CREATE OR REPLACE procedure DCYSTD4a
  (
     p_schedule_seq          IN     number, --schedule_seq
     p_schedule_type         IN     varchar2, --'S' for sample
     p_schedule_id           IN     number, --HSN
     p_cond_code             IN OUT varchar2, --null for a CALC, Schedule CC for a CAT
     p_cmp                   IN     varchar2, --CMP code (7440-41-7 for Be) calc, null for a CAT
     p_error_message         IN OUT varchar2)
IS

---------------------------------
--
--   NOTICE
--   HORIZON Lab Systems LLC (�HORIZON Lab Systems�) provides programming examples for practical illustration only.  
--   All such HORIZON Lab Systems examples, including the one in which this NOTICE appears, are provided �AS IS.�  
--   HORIZON Lab Systems DISCLAIMS ALL WARRANTIES WHETHER EXPRESS OR IMPLIED.  All HORIZON Lab Systems examples are 
--   to be used at your own risk.  This example program and any portion thereof may be used or modified only by the 
--   organization licensed by HORIZON Lab Systems under the terms of the applicable Software License Agreement 
--   between the organization and HORIZON Lab Systems, and only if this NOTICE is included unaltered in any such use 
--   or modification. HORIZON Lab Systems retains all ownership rights in this program regardless of use or 
--   modifications by other parties.
--   � 1991-2019 HORIZON Lab Systems, LLC. All rights reserved.
--
---------------------------------

/*
-----------------------------------------------------------------------------------
--LLNLCUSTOM, Custom LLNL for Standard Decay for GABT Swipes (GABH3SW)
--has special code to find the right half life when GA, GB, H3 spiked
--called by GABTSAMP for tritium

--LLNLCUSTOM, Custom LLNL for GABT Swipes by LSC
--Tested with batches 1576 AND Star Batch 20240395
v0 sdk 03/15/2023
v1 sdk 1/21/2025, approved by Phil Toretto 1/17/2025

sdk 2/10/2026 PB1 aux data template logic restricted to QC-56


-----------------------------------------------------------------------------------
*/

EXIT_ERROR            EXCEPTION; 
EXIT_NOERROR          EXCEPTION;
eExit                 EXCEPTION;
vGeneralException   EXCEPTION;
lErrMsg               VARCHAR2 (2000);

vImportantStdSeqForGABTLC number;
vImportantSpikedAmountRowsForPrepSchedule   number;

vSampleType varchar2(100);
vSampleTypeFlag varchar2(1);
vInstru map_to_runs.run_instru%type;
vInstruCode varchar2(1);
vRunDate    map_to_runs.run_date%type;
vBatchNum batch_schedules.batch_number%type;
vQueue batch_schedules.queue%type;
vBatchSeq   batches.batch_seq%type;

vCountCalcSpikes number;




vHalfLife   number;
vStdOrig    number;
vStdSeq number;
vOrigAct   number;
vStdOrigDate	standards.create_date%type;
vSrcCalDat varchar(10);
vDateDiffDays	number;
vStandardSeqNexVal  number;
vStandardRec standards%rowtype;
vStandardCmpsRec   standard_cmps%rowtype;
vDecayCorrectedNumber	number;
vCountSpike number;
vMeasAct   number;

vStandardAnalyteCount   number;


vGATheoretical number;
vGBTheoretical number;


vComment1 footnotes.custom_comment%type; --2000 char
vCountComment1 number;
vMaxCommentSort number;

vProcCode   schedules.proc_code%type;


--vPrepSchedule   number;
vStandardID standards.standard_id%type;

vGABTStdSeq number;
vGABTCALCStdSeq NUMBER;

vCountAuxDataRows number;
vAuxDataSeq number;

vPrepSchedule   number;

BEGIN 

   -- See the SysAdmin Guide for more information on TraceLog capabilities.
   -- Add this procedure call to the TraceLog. Pass in the name of this procedure.
   TraceLog.ProcBegin('DCYSTD4a');
   -- Show the input parameters
   TraceLog.Param('p_schedule_seq', p_schedule_seq);
   TraceLog.Param('p_schedule_type', p_schedule_type);
   TraceLog.Param('p_schedule_id', p_schedule_id);

   dbms_output.put_line('p_schedule_id = ' || p_schedule_id);

   TraceLog.Param('p_cond_code', p_cond_code);
   TraceLog.Param('p_cmp', p_cmp);
   dbms_output.put_line('p_cmp=  ' || p_cmp);




TraceLog.Message('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>Hello from procedure DCYSTD4a' );

begin
select thread
into vPrepSchedule
from schedules 
where schedule_seq = p_schedule_seq;
exception
when no_data_found then
    vPrepSchedule := ''; --ok to be null during prep posting
when too_many_rows then
    p_error_message := 'Too many rows getting vPrepSchedule';
    RAISE vGeneralException;
when others then
    p_error_message := 'Other error getting vPrepSchedule';
    RAISE vGeneralException;
end;

TraceLog.Message('vPrepSchedule =  ' || vPrepSchedule);

if (vPrepSchedule is null or vPrepSchedule = '')then   --sdk 2/6/2026
vPrepSchedule := p_Schedule_seq;
end if;

TraceLog.Message('vPrepSchedule (or Analyis for QC) =  ' || vPrepSchedule);


select count(*)
into vCountCalcSpikes
from spiked_amounts sa, standards s
where sa.standard_seq = s.standard_seq
and sa.lims_sequence = p_schedule_seq
and standard_id like '%CALC';

TraceLog.Message('vCountCalcSpikes =  ' || vCountCalcSpikes);

if vCountCalcSpikes = 0 then  --then do all the rest, else exit



begin
select run_instru, run_date, substr(run_instru,4,1)
into vInstru, vRunDate,vInstruCode
from map_to_runs
where schedule_seq = p_schedule_seq;
exception
when no_data_found then
   -- p_error_message := 'No Data found getting vInstru, vRunDate';
    TraceLog.Message('No Data found getting vInstru, vRunDate');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vInstru, vRunDate';
    TraceLog.Message('Too many rows getting vInstru, vRunDate');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vInstru, vRunDate';
 TraceLog.Message('Other error getting vInstru, vRunDate');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

TraceLog.Message('vInstru =  ' || vInstru);
TraceLog.Message('vInstruCode =  ' || vInstruCode);
TraceLog.Message('vRunDate =  ' || vRunDate);


select proc_code
into vProcCode
from schedules
where schedule_seq = p_schedule_seq;

TraceLog.Message('vProcCode =  ' || vProcCode);


            begin
                    select bs.queue,
                    bs.batch_number,
                    b.batch_seq
                    into vQueue,  vBatchNum, vBatchSeq
                    from batch_schedules bs, batches b
                    where bs.queue = b.queue
                    and bs.batch_number = b.batch_number
                    and bs.schedule_seq = P_SCHEDULE_seq;
                    exception
                      when others then
                        P_ERROR_MESSAGE := 'Unable to determine queue,  batch number and batch_seq for ' ||
                                          'schedule_seq ' || p_schedule_seq||'. '||to_char(sqlcode)||' '||substr(sqlerrm,1,200);
                                          TraceLog.Message('Unable to find queue, batch_number, batch_seq');
                        RAISE vGeneralException;

                  end;


                   TraceLog.Message('vQueue =  ' || vQueue);
                   TraceLog.Message('vBatchNum =  ' || vBatchNum);
                   TraceLog.Message('vBatchSeq =  ' || vBatchSeq);
                   
    begin
select hv.general_type_flag, hv.sample_type
into vSampleTypeFlag, vSampleType
from samples s, hv$sample_type hv
where s.sample_type = hv.sample_type
and s.hsn = p_schedule_id;
exception
when no_data_found then
    vSampleTypeFlag := '';
when too_many_rows then
    p_error_message := 'Too many rows getting vSampleTypeFlag';
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when OTHERS then
    p_error_message := 'Other error getting vSampleTypeFlag';
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
end;
TraceLog.Message('vSampleTypeFlag =  ' || vSampleTypeFlag);
dbms_output.put_line('vSampleTypeFlag=  ' || vSampleTypeFlag);
TraceLog.Message('vSampleType =  ' || vSampleType);
dbms_output.put_line('vSampleType=  ' || vSampleType);
                   

if vSampleType = 'QC-56' then 
select count(*)
into vCountAuxDataRows
from aux_data
where aux_data_format = 'PB1'
and aux_data_type = 'B'
and aux_data_id = vBatchSeq
and aux_field = 1;

TraceLog.Message('vCountAuxDataRows =  ' || vCountAuxDataRows);
--be sure to delete this if troubleshooting QC-56

begin
select aux_data
into vGABTStdSeq
from aux_data 
where aux_data_format = 'PB1'
and aux_field = 1
and aux_data_type = 'B'
and aux_data_id = vBatchSeq;
exception
when no_data_found then
vGABTStdSeq := '';
when too_many_rows then
   -- p_error_message := 'Too many rows getting vGABTStdSeq';
    TraceLog.Message('Too many rows getting vGABTStdSeq');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vGABTStdSeq';
 TraceLog.Message('Other error getting vGABTStdSeq');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

TraceLog.Message('vGABTStdSeq at very beginnning from aux data =  ' || vGABTStdSeq);
end if; --if vSampleType = 'QC-56' then 




if vSampleType IN ( 'QC-53') then

begin
delete spiked_amounts
where lims_sequence = P_SCHEDULE_SEQ
and standard_seq in (select standard_SEQ from standards where standard_id like 'QC53-%'
and standard_id != 'QC53-'||vInstruCode);
    exception
when others then
 TraceLog.Message('Other error deleting QC53- spikes '||sqlerrm(sqlcode));
 raise vGeneralException;
end;
TraceLog.Message('Extra QC53- spikes deleted for other instruments');



begin
        SELECT --sa.standard_seq, 
        s.standard_id--, 
        into vStandardID
    FROM SPIKED_AMOUNTS sa, standards s 
    where sa.standard_seq = s.standard_seq
    --and sa.lims_sequence = vPrepSchedule
    and sa.lims_sequence = P_SCHEDULE_SEQ
    and s.standard_id = 'QC53-'||vInstruCode;
    exception
when no_data_found then
    TraceLog.Message('No Data found getting vStandardID for QC-53');
   raise vGeneralException;
when too_many_rows then
    TraceLog.Message('Too many rows getting vStandardID for QC-53');
    raise vGeneralException;
when others then
 TraceLog.Message('Other error getting vStandardID for QC-53');
 raise vGeneralException;
end;

TraceLog.Message('vStandardID for QC-53 = ' || vStandardID);

elsif vSampleType in ('QC-54') then

begin
delete spiked_amounts
where lims_sequence = p_schedule_seq
and standard_seq in (select standard_SEQ from standards where standard_id like 'QC54-%'
and standard_id != 'QC54-'||vInstruCode);
    exception
when others then
 TraceLog.Message('Other error deleting QC54- spikes '||sqlerrm(sqlcode));
-- TraceLog.ProcEnd(true);
raise vGeneralException;
end;

TraceLog.Message('332 Extra QC54- spikes deleted for ALL other instruments ');

begin
        SELECT --sa.standard_seq, 
        s.standard_id--, 
        --sa.lims_sequence
        into vStandardID
    FROM SPIKED_AMOUNTS sa, standards s 
    where sa.standard_seq = s.standard_seq
    and sa.lims_sequence = p_schedule_seq
    and s.standard_id = 'QC54-'||vInstruCode;
    exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStandardID for GBLCS';
    TraceLog.Message('No Data found getting vStandardID for GBLCS');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStandardID for GBLCS';
    TraceLog.Message('Too many rows getting vStandardID for GBLCS');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStandardID for GBLCS';
 TraceLog.Message('Other error getting vStandardID for GBLCS');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
 end;


    TraceLog.Message('vStandardID for QC-54 = ' || vStandardID);

elsif vSampleType IN ('QC-55') then

begin
delete spiked_amounts
--where lims_sequence = vPrepSchedule
where lims_sequence = P_SCHEDULE_SEQ
and standard_seq in (select standard_SEQ from standards where standard_id like 'QC55-%'
and standard_id != 'QC55-'||vInstruCode);
    exception
when others then
--p_error_message := 'Other error getting vInstru, vRunDate';
 TraceLog.Message('Other error deleting QC55- spikes '||sqlerrm(sqlcode));
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

    TraceLog.Message('384 Extra QC55- spikes deleted for other instruments ');


begin
        SELECT --sa.standard_seq, 
        s.standard_id--, 
        --sa.lims_sequence
        into vStandardID
    FROM SPIKED_AMOUNTS sa, standards s 
    where sa.standard_seq = s.standard_seq
    --and sa.lims_sequence = vPrepSchedule
    and sa.lims_sequence = P_SCHEDULE_SEQ
    and s.standard_id = 'QC55-'||vInstruCode;
    exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStandardID for H3LCS';
    TraceLog.Message('No Data found getting vStandardID for QC-55');
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStandardID for H3LCS';
    TraceLog.Message('Too many rows getting vStandardID for QC-55');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vInstru, vRunDate';
 TraceLog.Message('Other error getting vStandardID for QC-55');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;
TraceLog.Message('vStandardID for QC-55 = ' || vStandardID);

elsif vSampleType IN  ('QC-11') then

begin
delete spiked_amounts
--where lims_sequence = vPrepSchedule
where lims_sequence = P_SCHEDULE_SEQ
and standard_seq in (select standard_SEQ from standards where standard_id like 'QC11-%'
and standard_id != 'QC11-'||vInstruCode);
    exception
when others then
--p_error_message := 'Other error getting vInstru, vRunDate';
 TraceLog.Message('Other error deleting QC11- spikes'||sqlerrm(sqlcode));
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;


begin
        SELECT --sa.standard_seq, 
        s.standard_id--, 
        --sa.lims_sequence
        into vStandardID
    FROM SPIKED_AMOUNTS sa, standards s 
    where sa.standard_seq = s.standard_seq
    --and sa.lims_sequence = vPrepSchedule
    and sa.lims_sequence = P_SCHEDULE_SEQ
    and s.standard_id = 'QC11-'||vInstruCode;
    exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStandardID for H3LCS2';
    TraceLog.Message('No Data found getting vStandardID for QC-11');
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStandardID for H3LCS2';
    TraceLog.Message('Too many rows getting vStandardID for QC-11');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStandardID for H3LCS2';
 TraceLog.Message('Other error getting vStandardID for QC-11');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;


    TraceLog.Message('549 vStandardID for QC-11 = ' || vStandardID);

elsif vSampleType IN ( 'QC-56') then

if (p_cmp != 'Tritium' and vGABTStdSeq is not null) then
TraceLog.Message('579 Going to Patch Spiked_amounts for QC-56');
TraceLog.Message('vGABTStdSeq before patching = '||vGABTStdSeq); --appears in trace log

--THERE ARE NO ROWS IN SPIKED_AMOUNTS AT THIS MOMENT IN TIME TO UPDATE 11/28

                begin
                INSERT INTO SPIKED_AMOUNTS (CREATE_DATE, FLAGS, LIMS_SEQUENCE, SEQUENCE_TYPE, SPIKE_VOLUME, STANDARD_SEQ, USER_NBR)
                VALUES (SYSDATE, 'j..D......', p_schedule_seq, 'S', 1, vGABTStdSeq, 'CW');
                exception
                when others then
                    TraceLog.Message('Error inserting vGABTStdSeq into spiked_amounts = '||SQLERRM(SQLCODE));
                    RAISE vGeneralException;
                end;
         
                    delete spiked_amounts where lims_sequence = p_schedule_seq
                    and standard_seq in (select standard_seq from standards where standard_id = vStandardID)
                    and standard_seq != vGABTStdSeq;



TraceLog.Message('Patched QC-56 spiked_amounts (not in Tritium)');

end if; --if (p_cmp != 'Tritium' and vGABTStdSeq is not null) then


begin
        SELECT --sa.standard_seq, 
        s.standard_id--, 
        --sa.lims_sequence
        into vStandardID
    FROM SPIKED_AMOUNTS sa, standards s 
    where sa.standard_seq = s.standard_seq
    --and sa.lims_sequence = vPrepSchedule
    and sa.lims_sequence = p_schedule_seq
    and s.standard_id = 'QC56-'||vInstruCode;
    exception
when no_data_found then
    vStandardID := ''; --sdk 09/12/2023, it will get updated later via DCYGAGB
   -- TraceLog.Message('No Data found getting vStandardID for GABTLC IN DCYSTD4a');
   -- raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStandardID for GABTLC';
    TraceLog.Message('632 Too many rows getting vStandardID for QC-56');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStandardID for GABTLC';
 TraceLog.Message('Other error getting vStandardID for QC-56');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

TraceLog.Message('vStandardID for QC-56 = ' || vStandardID); --getting QC56-E for batch 1438
TraceLog.Message('p_schedule_seq = ' || p_schedule_seq); 
TraceLog.Message('vStandardID = ' || vStandardID); 
delete spiked_amounts where lims_sequence = p_schedule_seq
and standard_seq not in (select distinct standard_seq from standards where standard_id = vStandardID);
TraceLog.Message('647 Prep Spiked Amounts cleaned up for QC-56 all EXCEPT vInstruCode = ' || vInstruCode);
TraceLog.Message('650 end QC-56');
end if; --if vSampleType in various different sample types


if vSampleType in ('QC-2', 'QC-3', 'QC-4') then

if  vSampleType IN ( 'QC-2') then

delete spiked_amounts
where lims_sequence = p_schedule_seq
and standard_seq in (select standard_SEQ from standards where standard_id like 'QC2-%'
and standard_id != 'QC2-'||vInstruCode);


TraceLog.Message('667 QC2- deleted from spiked amounts EXCEPT for vInstruCode =  ' || vInstruCode);


begin
        SELECT --sa.standard_seq, 
        s.standard_id--, 
        --sa.lims_sequence
        into vStandardID
    FROM SPIKED_AMOUNTS sa, standards s 
    where sa.standard_seq = s.standard_seq
    and sa.lims_sequence = p_schedule_seq
    and s.standard_id = 'QC2-'||vInstruCode;
    exception
when no_data_found then
    vStandardID := '';
   -- p_error_message := 'No Data found getting vStandardID';
    TraceLog.Message('No Data found getting vStandardID for QC-2');
    --TraceLog.ProcEnd(true);
    --raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStandardID';
    TraceLog.Message('Too many rows getting vStandardID for QC-2');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStandardID';
 TraceLog.Message('Other error getting vStandardID for QC-2');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

        TraceLog.Message('vStandardID for ICV QC-2 = ' || vStandardID);


elsif vSampleType IN ( 'QC-3') then 

delete spiked_amounts --all the other instruments
where lims_sequence = p_schedule_seq
and standard_seq in (select standard_SEQ from standards where standard_id like 'QC3-%'
and standard_id != 'QC3-'||vInstruCode);


TraceLog.Message('QC3- deleted from spiked amounts EXCEPT for vInstruCode =  ' || vInstruCode);

begin
        SELECT --sa.standard_seq, 
        s.standard_id--, 
        --sa.lims_sequence
        into vStandardID
    FROM SPIKED_AMOUNTS sa, standards s 
    where sa.standard_seq = s.standard_seq
    and sa.lims_sequence = p_schedule_seq
    and s.standard_id = 'QC3-'||vInstruCode;
    exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStandardID';
    TraceLog.Message('No Data found getting vStandardID for QC-3');
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStandardID';
    TraceLog.Message('Too many rows getting vStandardID for QC-3');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStandardID';
 TraceLog.Message('Other error getting vStandardID for QC-3');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

TraceLog.Message('vStandardID for ICV QC-3 = ' || vStandardID);

elsif vSampleType IN ( 'QC-4') then 


    delete spiked_amounts
where lims_sequence = p_schedule_seq
and standard_seq in (select standard_SEQ from standards where standard_id like 'QC4-%'
and standard_id != 'QC4-'||vInstruCode);

TraceLog.Message('607 QC4- deleted from spiked amounts EXCEPT for vInstruCode =  ' || vInstruCode);

BEGIN
        SELECT --sa.standard_seq, 
        s.standard_id--, 
        --sa.lims_sequence
        into vStandardID
    FROM SPIKED_AMOUNTS sa, standards s 
    where sa.standard_seq = s.standard_seq
    and sa.lims_sequence = p_schedule_seq
    and s.standard_id = 'QC4-'||vInstruCode;
    exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStandardID';
    TraceLog.Message('No Data found getting vStandardID for QC-4');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStandardID';
    TraceLog.Message('Too many rows getting vStandardID for QC-4');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStandardID';
 TraceLog.Message('Other error getting vStandardID for QC-4');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

        TraceLog.Message('vStandardID for QC-4 = ' || vStandardID);



end if; --if  vSampleType = 'ICV2' then

    TraceLog.Message('Analysis vStandardID AFTER ALL SAMPLE TYPES =  ' || vStandardID);
TraceLog.Message('Analysis Spiked Amounts cleaned up for all EXCEPT vInstruCode = ' || vInstruCode);


end if; --380 if vSampleType in ( 'QC-2', 'QC-3', 'QC-4') then





--begin spike Decay
--Get the un-decayed StandardSeq per instrument and per mappings in utility table
--if vSampleType in ( 'QC-53',  'QC-54', 'QC-55', 'QC-11', 'QC-56',   'QC-2', 'QC-3', 'QC-4', 'QC-6') then 
if vSampleType in ( 'QC-53',  'QC-54', 'QC-55', 'QC-11', 'QC-56',   'QC-2', 'QC-3', 'QC-4') then 
if vStandardID not like '%CALC%' then 

TraceLog.Message('Inside SPIKE DECAY area for all QC sample types');


TraceLog.Message('vStandardID =  ' || vStandardID);
TraceLog.Message('vInstru =  ' || vInstru);
TraceLog.Message('vSampleType =  ' || vSampleType);

BEGIN
select DISTINCT STANDARD_SEQ
into vStdSeq
FROM USR$RML_LSC
WHERE standard_id = vStandardID
AND INSTRU = vInstru
AND SAMPLE_TYPE = vSampleType;
exception
when no_data_found then
    TraceLog.Message('No Data found getting vStdSeq for sample type = '||vSampleType);
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when too_many_rows then
    TraceLog.Message('Too many rows getting vStdSeq for sample type = '||vSampleType);
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when others then
 TraceLog.Message('Other error getting vStdSeq for sample type = '||vSampleType);
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

TraceLog.Message('838 vStdSeq =  ' || vStdSeq);


select count(*)
into vStandardAnalyteCount
from standard_cmps
where standard_seq = vStdSeq;

TraceLog.Message('vStandardAnalyteCount =  ' || vStandardAnalyteCount);

if vSampleType = 'QC-6' then 
begin
select amount 
into vOrigAct
from standard_cmps
where cmp = p_cmp||'-E2'
and standard_seq = vStdSeq;
exception
when no_data_found then
   -- p_error_message := 'No Data found getting vOrigAct';
    TraceLog.Message('No Data found getting vOrigAct for QC-6');
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vOrigAct';
    TraceLog.Message('Too many rows getting vOrigAct for QC-6');
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when others then
--p_error_message := 'Other error getting vOrigAct';
 TraceLog.Message('Other error getting vOrigAct for QC-6');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;


TraceLog.Message('QC-6 vOrigAct =  ' || vOrigAct ||' For cmp = '||'Tritium-E2');
else
begin
select amount 
into vOrigAct
from standard_cmps
where cmp = p_cmp
and standard_seq = vStdSeq;
exception
when no_data_found then
   -- p_error_message := 'No Data found getting vOrigAct';
    TraceLog.Message('No Data found getting vOrigAct for QC-6');
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vOrigAct';
    TraceLog.Message('Too many rows getting vOrigAct for QC-6');
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when others then
--p_error_message := 'Other error getting vOrigAct';
 TraceLog.Message('Other error getting vOrigAct for QC-6');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;


TraceLog.Message('QC-6 vOrigAct =  ' || vOrigAct ||' For cmp = '||p_cmp);
end if;

--Date Diff
begin
select create_date
into vStdOrigDate
from standards where standard_seq = vStdSeq;
exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStdOrigDate';
    TraceLog.Message('No Data found getting vStdOrigDate');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStdOrigDate';
    TraceLog.Message('Too many rows getting vStdOrigDate');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStdOrigDate';
 TraceLog.Message('Other error getting vStdOrigDate');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

TraceLog.Message('vStdOrigDate =  ' || vStdOrigDate);
dbms_output.put_line('vStdOrigDate=  ' || vStdOrigDate);

begin
select to_char(create_date, 'MM/DD/YYYY')
into vSrcCalDat
from standards where standard_seq = vStdSeq;
exception
when no_data_found then
   -- p_error_message := 'No Data found getting vSrcCalDat';
    TraceLog.Message('No Data found getting vSrcCalDat');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vSrcCalDat';
    TraceLog.Message('Too many rows getting vSrcCalDat');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vSrcCalDat';
 TraceLog.Message('Other error getting vSrcCalDat');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

TraceLog.Message('vSrcCalDat =  ' || vSrcCalDat);

if vSrcCalDat is not null then
SELECT trunc(vRunDate) -  trunc(vStdOrigDate) 
into vDateDiffDays
FROM dual;
end if;

TraceLog.Message('vDateDiffDays =  ' || vDateDiffDays);


if p_cmp = 'GROSSALPHA' then
    BEGIN
select to_number(edd_value)
into vHalfLife
from edd_mapper
where edd_format = 'DECAY'
and code_type = 'CMP'
and horizon_value = 'GROSSALPHA'
AND FLAGS = vProcCode;
    exception
    when no_data_found then
        TraceLog.Message('No Data found getting vHalfLife');
        --TraceLog.ProcEnd(true);
        raise vGeneralException;
    when too_many_rows then
        TraceLog.Message('Too many rows getting vHalfLife');
        --TraceLog.ProcEnd(true);
        raise vGeneralException;
    when others then
     TraceLog.Message('Other error getting vHalfLife');
    -- TraceLog.ProcEnd(true);
    raise vGeneralException;
    end;

    TraceLog.Message('vHalfLife =  ' || vHalfLife);
elsif p_cmp = 'GROSSBETA' then
    BEGIN
select to_number(edd_value)
into vHalfLife
from edd_mapper
where edd_format = 'DECAY'
and code_type = 'CMP'
and horizon_value = 'GROSSBETA'
AND FLAGS = vProcCode;
    exception
    when no_data_found then
        TraceLog.Message('No Data found getting vHalfLife');
        --TraceLog.ProcEnd(true);
        raise vGeneralException;
    when too_many_rows then
        TraceLog.Message('Too many rows getting vHalfLife');
        --TraceLog.ProcEnd(true);
        raise vGeneralException;
    when others then
     TraceLog.Message('Other error getting vHalfLife');
     --TraceLog.ProcEnd(true);
     raise vGeneralException;
    end;

    TraceLog.Message('vHalfLife =  ' || vHalfLife);
elsif p_cmp = 'Tritium' then
    BEGIN
    select to_number(edd_value)
into vHalfLife
from edd_mapper
where edd_format = 'DECAY'
and code_type = 'CMP'
and horizon_value = 'Tritium'
AND FLAGS IS NULL;
    exception
    when no_data_found then
        TraceLog.Message('No Data found getting vHalfLife');
       raise vGeneralException;
    when too_many_rows then
        TraceLog.Message('Too many rows getting vHalfLife');
        --TraceLog.ProcEnd(true);
        raise vGeneralException;
    when others then
     TraceLog.Message('Other error getting vHalfLife');
     --TraceLog.ProcEnd(true);
     raise vGeneralException;
    end;

TraceLog.Message('vHalfLife =  ' || vHalfLife);
end if; 


--original spike conc
if vSampleType = 'QC-6' then 

begin
select amount
into vStdOrig
from standard_cmps where standard_seq = vStdSeq
AND CMP = P_CMP||'-E2';
exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStdOrig';
    TraceLog.Message('No Data found getting vStdOrig for QC-6');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStdOrig';
    TraceLog.Message('Too many rows getting vStdOrig for QC-6');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStdOrig';
 TraceLog.Message('Other error getting vStdOrig for QC-6');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

TraceLog.Message('vStdOrig for QC-6 =  ' || vStdOrig);

else


begin
select amount
into vStdOrig
from standard_cmps where standard_seq = vStdSeq
AND CMP = P_CMP;
exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStdOrig';
    TraceLog.Message('No Data found getting vStdOrig for QC-6');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStdOrig';
    TraceLog.Message('Too many rows getting vStdOrig for QC-6');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStdOrig';
 TraceLog.Message('Other error getting vStdOrig for QC-6');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;



TraceLog.Message('vStdOrig =  ' || vStdOrig);
end if;


TraceLog.Message('1186 vOrigAct =  ' || vOrigAct);
TraceLog.Message('1187 vHalfLife =  ' || vHalfLife);
TraceLog.Message('1188 vDateDiffDays =  ' || vDateDiffDays);

vDecayCorrectedNumber := round((vOrigAct * EXP(-(LN(2)/(vHalfLife*365.25))*vDateDiffDays)),2);

TraceLog.Message('p_cmp =  ' || p_cmp);
TraceLog.Message('vStdSeq =  ' || vStdSeq);
TraceLog.Message('vGABTStdSeq =  ' || vGABTStdSeq);
TraceLog.Message('vCountAuxDataRows =  ' || vCountAuxDataRows);
TraceLog.Message('vDecayCorrectedNumber =  ' || vDecayCorrectedNumber);

--End Spike Decay Correction
end if; --if vStandardID not like '%CALC%' then 
end if; --if vSampleType in ('GALCS', 'GBLCS', 'H3LCS', 'GABTLC', 'ICV2', 'ICV3', 'ICV4', 'QC-2', 'QC-3', 'QC-4') then 

--NOW THAT WE HAVE THE ADJUSTED CONCENTRATION, INSERT A STANDARDS RECORD AND UPDATE SPIKED_AMOUNTS TO REFERENCE IT
--SO FAR THIS ONLY WORKS WHEN YOU HAVE A STANDARD WITH ONE ANALYTE
if vStandardAnalyteCount = 1 then  --should work for 'QC-2', 'QC-3', 'QC-4'

TraceLog.Message('Inside Area for Inserts for Single Analyte.');

        select standard_seq.nextval 
          into vStandardSeqNexVal
          from dual;

TraceLog.Message('993 vStandardSeqNexVal =  ' || vStandardSeqNexVal);


--GET all THE STANDARDS fields
begin
    select *
    into vStandardRec
    from standards st
    where st.standard_seq = vStdSeq;
    exception
    when no_data_found then
       p_error_message := p_error_message || 'No Data Found Getting all rows for vStandardRec in calc DCYSTD4a.' || sqlerrm(sqlerrm);
      -- TraceLog.ProcEnd(true);
      raise vGeneralException;
     when too_many_rows then
       p_error_message := p_error_message || 'Too many rows Found Getting vStandardRec in calc DCYSTD4a.' || sqlerrm(sqlerrm);
      -- TraceLog.ProcEnd(true);
      raise vGeneralException;
     when others then
       p_error_message := p_error_message || 'Unhandled Exception Getting vStandardRec in calc DCYSTD4a.' || sqlerrm(sqlerrm);
       --TraceLog.ProcEnd(true);
       raise vGeneralException;
end;

TraceLog.Message('vStdSeq =  ' || vStdSeq);


TraceLog.Message('vDecayCorrectedNumber =  ' || vDecayCorrectedNumber);
TraceLog.Message('vStandardSeqNexVal =  ' || vStandardSeqNexVal);

if vSampleType = 'QC-6' then
        BEGIN
        insert into standard_cmps (amount,CMP, SORT_ITEM,standard_seq, flags)
        values (vDecayCorrectedNumber, 'Tritium-E2',1,vStandardSeqNexVal, '%'); --flags = units of %pm
        
        TraceLog.Message('1254 inserted standard_cmps for QC-6 for pCmp = '||p_cmp); --geting here in dev
        
        exception
             when others then
               p_error_message := p_error_message || 'Unhandled Exception on insert to std_cmps for QC-6.' || sqlerrm(sqlerrm);
               TraceLog.ProcEnd(true);
        end;
else --qc2 and others
        BEGIN
        insert into standard_cmps (amount,CMP, SORT_ITEM,standard_seq, flags)
        values (vDecayCorrectedNumber, p_cmp,1,vStandardSeqNexVal, '-'); --flags = dpm
        
        TraceLog.Message('1266 inserted standard_cmps for other than QC-6 for pCmp = '||p_cmp); --geting here in dev
        
        exception
             when others then
               p_error_message := p_error_message || 'Unhandled Exception on insert to std_cmps for QC-6.' || sqlerrm(sqlerrm);
               TraceLog.ProcEnd(true);
        end;
end if;




begin

insert into standards (standard_seq,create_date,create_user, expire_date, flags, lot_id, MANUFACTURER,
NOTE,owner_lab, standard_id)
values (vStandardSeqNexVal, vStandardRec.create_date, 'CW',vStandardRec.expire_date, vStandardRec.flags,vStandardRec.lot_id, vStandardRec.MANUFACTURER, 
'Adjusted for decay from standard_seq '||vStdSeq||'('||to_char(sysdate, 'MMDDYYYY')||')', 's', vStandardID||'CALC');



TraceLog.Message('1286  inserted standards for standard_seq = '||vStandardSeqNexVal); 
exception
     when others then
       p_error_message := p_error_message || '1289 Unhandled Exception on insert standards.' || sqlerrm(sqlerrm);
      -- TraceLog.ProcEnd(true);
      raise vGeneralException;
end;

if vSampleType in (  'QC-2', 'QC-3', 'QC-4', 'QC-53', 'QC-54','QC-55','QC-11', 'QC-6') then 
        if vSampleType = 'QC-6' then
        select count(*)
        into vCountSpike
        from spiked_amounts sa, standards std
        where sa.standard_seq = std.standard_seq
        and sa.lims_sequence = vPrepSchedule
        and std.standard_id = vStandardID||'CALC'
        AND sa.STANDARD_SEQ != vStdSeq;
        
        TraceLog.Message('1078 vCountSpike =  ' || vCountSpike);

        else
        select count(*)
        into vCountSpike
        from spiked_amounts sa, standards std
        where sa.standard_seq = std.standard_seq
        and sa.lims_sequence = p_schedule_seq
        and std.standard_id = vStandardID||'CALC'
        AND sa.STANDARD_SEQ != vStdSeq;
        
        TraceLog.Message('1089 vCountSpike =  ' || vCountSpike);
        end if;


if vCountSpike = 0 then


TraceLog.Message('1327 vStdSeq =  ' || vStdSeq);

if vSampleType = 'QC-6' then
        begin
        INSERT INTO SPIKED_AMOUNTS (CREATE_DATE, FLAGS, LIMS_SEQUENCE, SEQUENCE_TYPE, SPIKE_VOLUME, STANDARD_SEQ, USER_NBR)
        VALUES (SYSDATE, 'j..D......', vPrepSchedule, 'S', 1, vStandardSeqNexVal, 'CW');
        
        TraceLog.Message('1339 Inserted QC-6 spike amounts for StdSeq ' || vStandardSeqNexVal ||' for p_cmp = '||p_cmp);
        exception
        when others then
            TraceLog.Message('1343 Error inserting QC-6 into spiked_amounts = '||SQLERRM(SQLCODE));
            TraceLog.ProcEnd(true);
        end;
        

        ELSE
        begin
        INSERT INTO SPIKED_AMOUNTS (CREATE_DATE, FLAGS, LIMS_SEQUENCE, SEQUENCE_TYPE, SPIKE_VOLUME, STANDARD_SEQ, USER_NBR)
        VALUES (SYSDATE, 'j..D......', p_schedule_seq, 'S', 1, vStandardSeqNexVal, 'CW');
                TraceLog.Message('1352 Inserted QC-6 spike amounts for StdSeq ' || vStandardSeqNexVal ||' for p_cmp = '||p_cmp);
        exception
        when others then
            TraceLog.Message('1356 Error inserting QC-6 into spiked_amounts = '||SQLERRM(SQLCODE));
            TraceLog.ProcEnd(true);
        end;
        
END IF;

end if; --if vCountSpike = 0 then
end if; --if vSampleType in ( 'QC-2', 'QC-3', 'QC-4') then 
end if; --if vStandardAnalyteCount = 1 then


--special handing GABTLC here (because it has 3 analytes)

if vStandardAnalyteCount = 3 then  --should work for GABTLC
TraceLog.Message('1132 Special handing for analyte count = 3 ');
TraceLog.Message(' 1133 ONE p_cmp  =  ' || p_cmp);
if p_cmp = 'Tritium' then


        begin
        select standard_seq.nextval 
          into vStandardSeqNexVal
          from dual;
          exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStandardSeqNexVal';
    TraceLog.Message('No Data found getting vStandardSeqNexVal');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStandardSeqNexVal';
    TraceLog.Message('Too many rows getting vStandardSeqNexVal');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStandardSeqNexVal';
 TraceLog.Message('Other error getting vStandardSeqNexVal');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;




        TraceLog.Message('1460 THE NEW vStandardSeqNexVal for QC-56 =  ' || vStandardSeqNexVal);
        vGABTStdSeq :=  vStandardSeqNexVal;
        TraceLog.Message('THE NEW vGABTStdSeq =  ' || vGABTStdSeq);

            --FIRST INSTANCE OF THE NEWLY CREATED STANDARD

        TraceLog.Message('vCountAuxDataRows  =  ' || vCountAuxDataRows);
        dbms_output.put_line('vCountAuxDataRows =  ' || vCountAuxDataRows);

            --put it into aux data (possible to delete later)
            if vCountAuxDataRows = 0 then



                   select aux_data_seq.nextval 
                   into vAuxDataSeq from dual;

TraceLog.Message(' 1478 ONE p_cmp =  ' || p_cmp);
TraceLog.Message('1479 OLD vStdSeq =  ' || vStdSeq);
TraceLog.Message('1480 vGABTStdSeq =  ' || vGABTStdSeq);
TraceLog.Message('1481 vCountAuxDataRows =  ' || vCountAuxDataRows);
TraceLog.Message('1481 DecayCorrectedNumber =  ' || vDecayCorrectedNumber);
--TraceLog.Message('1483 Freshly pulled vAuxDataSeq =  ' || vAuxDataSeq);         


TraceLog.Message('1485 vStandardSeqNexVal =  ' || vAuxDataSeq);   
TraceLog.Message('1486 vBatchSeq =  ' || vBatchSeq);   
TraceLog.Message('1487 Freshly pulled vAuxDataSeq =  ' || vAuxDataSeq);   


if vSampleType = 'QC-56' then --sdk 2/10/2026
                    
                    insert into aux_data (aux_data_seq, aux_data, aux_data_format, aux_data_id, aux_data_type, aux_field, archive_vol)
                    values (vAuxDataSeq,vStandardSeqNexVal,'PB1', vBatchSeq,'B',1,null);
                    
                    TraceLog.Message('>>>>>>>>>>>Aux insert SHOULD HAVE HAPPENED for NEW STANDARD = '||vStandardSeqNexVal);
end if;--if vSampleType = 'QC-56' then 


--THIS IS HAPPENING
TraceLog.Message(' TWO p_cmp  =  ' || p_cmp);
if p_cmp = 'GROSSALPHA' then 

--get the standard_seq already inserted for the schedule from aux_data

if vSampleType = 'QC-56' then --sdk 02/10/2026
                    insert into aux_data (aux_data, aux_data_format, aux_data_id, aux_data_seq, aux_data_type, aux_field, archive_vol)
                    values (vDecayCorrectedNumber,'PB1',vBatchSeq,vAuxDataSeq,'B',2,null);
        TraceLog.Message('GROSSALPHA PB1 Batch Aux data 2 inserted for vDecayCorrectedNumber = '||vDecayCorrectedNumber);
end if; --if vSampleType = 'QC-56' then 
end if;


TraceLog.Message('1215 OLD vStdSeq =  ' || vStdSeq);
TraceLog.Message('NEW vGABTStdSeq =  ' || vGABTStdSeq);
TraceLog.Message('vCountAuxDataRows =  ' || vCountAuxDataRows);
TraceLog.Message('1517 vDecayCorrectedNumber =  ' || vDecayCorrectedNumber);
TraceLog.Message('Freshly pulled vAuxDataSeq =  ' || vAuxDataSeq); 


TraceLog.Message(' THREE p_cmp =  ' || p_cmp);
if p_cmp = 'GROSSBETA' then 
if vSampleType = 'QC-56' then --sdk 2/10/2026

                    insert into aux_data (aux_data, aux_data_format, aux_data_id, aux_data_seq, aux_data_type, aux_field, archive_vol)
                    values (vDecayCorrectedNumber,'PB1',vBatchSeq,vAuxDataSeq,'B',3,null);
        TraceLog.Message('GROSSBETA PB1 Batch Aux data 3 inserted for vDecayCorrectedNumber = '||vDecayCorrectedNumber);
end if; --if vSampleType = 'QC-56' then 
end if;




            else 
            
            if vSampleType = 'QC-56' then --sdk 2/10/2026
                update aux_data 
                set aux_data = vStandardSeqNexVal
                where aux_data_format = 'PB1'
                and aux_data_id = vBatchSeq
                and aux_data_type = 'B'
                and aux_field = 1;
            end if; --if vSampleType = 'QC-56' then 
            end if; --if vCountAuxDataRows = 0 then
end if;  --if p_cmp = 'Tritium' then




--GET all THE STANDARDS fields
if p_cmp = 'Tritium' then
begin
    select *
    into vStandardRec
    from standards st
    where st.standard_seq = vStdSeq;
exception
when no_data_found then
   -- p_error_message := 'No Data found getting vStandardRec';
    TraceLog.Message('No Data found getting vStandardRec');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when too_many_rows then
   -- p_error_message := 'Too many rows getting vStandardRec';
    TraceLog.Message('Too many rows getting vStandardRec');
   --TraceLog.ProcEnd(true);
   raise vGeneralException;
when others then
--p_error_message := 'Other error getting vStandardRec';
 TraceLog.Message('Other error getting vStandardRec');
-- TraceLog.ProcEnd(true);
raise vGeneralException;
end;
end if; --if p_cmp = 'Tritium' then

TraceLog.Message('1270 All standard rows pulled for  =  ' || vStdSeq); 

--INSERT TO STANDARDS just for Tritium

TraceLog.Message('1573 Decay corrected value for Tritium just before insert to standard_cmps  ' || vDecayCorrectedNumber); 

if p_cmp = 'Tritium' then
BEGIN
insert into standard_cmps (amount,CMP, SORT_ITEM,standard_seq, flags)
values (vDecayCorrectedNumber, p_cmp,1,vStandardSeqNexVal, '-'); --flags = dpm
TraceLog.Message('Inserted standard_cmps row for Tritium.');
dbms_output.put_line('Inserted standard_cmps row for Tritium.');
exception
     when others then
       p_error_message := p_error_message || 'Unhandled Exception on insert to std_cmps.' || sqlerrm(sqlerrm);
       TraceLog.ProcEnd(true);
end;

begin

insert into standards (standard_seq,create_date,create_user, expire_date, flags, lot_id, MANUFACTURER,
NOTE,owner_lab, standard_id)
values (vStandardSeqNexVal, vStandardRec.create_date, 'CW',vStandardRec.expire_date, vStandardRec.flags,vStandardRec.lot_id, vStandardRec.MANUFACTURER, 
'Adjusted for decay from standard_seq '||vStdSeq||'('||to_char(sysdate, 'MMDDYYYY')||')', 's', vStandardID||'CALC');


TraceLog.Message('Inserted standards row for GABTLC via p_cmp = '||p_cmp);
dbms_output.put_line('Inserted standards row for GABTLC via p_cmp = '||p_cmp);
exception
     when others then
       p_error_message := p_error_message || 'Unhandled Exception on insert to GABH3SW-CALC standards.' || sqlerrm(sqlerrm);
       TraceLog.ProcEnd(true);
end;
end if; --if p_cmp = 'Tritium' then


if vSampleType in ('QC-56') then 
if p_cmp = 'Tritium' then --only do this one time
TraceLog.Message('Inside Tritium');
TraceLog.Message('Must be GA or GB, get the newest QC-56 CALC StdSeq from Batch Aux Data');
begin
select aux_data
into vGABTStdSeq
from aux_data 
where aux_data_format = 'PB1'
and aux_field = 1
and aux_data_type = 'B'
and aux_data_id = vBatchSeq;
exception
when no_data_found then
vGABTStdSeq := '';
when too_many_rows then
   -- p_error_message := 'Too many rows getting vGABTStdSeq';
    TraceLog.Message('Too many rows getting QC-56 vGABTStdSeq');
   -- TraceLog.ProcEnd(true);
   raise vGeneralException;
when others then
--p_error_message := 'Other error getting vGABTStdSeq';
 TraceLog.Message('Other error getting QC-56 vGABTStdSeq');
 --TraceLog.ProcEnd(true);
 raise vGeneralException;
end;

TraceLog.Message('1732 vGABTStdSeq for QC-56 =  ' || vGABTStdSeq);


select count(*)
into vCountSpike
from spiked_amounts sa, standards std
where sa.standard_seq = std.standard_seq
and sa.lims_sequence = p_schedule_seq
and std.standard_id = vStandardID||'CALC'
AND sa.STANDARD_SEQ != vStdSeq;

TraceLog.Message('IMPORTANT QC-56 vCountSpike =  ' || vCountSpike);
dbms_output.put_line('IMPORTANT vCountSpike=  ' || vCountSpike);


if vCountSpike = 0 then
TraceLog.Message('1648 vStdSeq =  ' || vStdSeq);
TraceLog.Message('1649vGABTStdSeq =  ' || vGABTStdSeq);
if vGABTStdSeq is not null then
--don't delete/insert...just update
update spiked_amounts set standard_seq = vGABTStdSeq
where standard_seq = vStdSeq
and lims_sequence in (p_schedule_seq, vPrepSchedule); --sdk 3/26/25

else
--THIS IS WORKING

TraceLog.Message('1658 QC-56 vStandardSeqNexVal before insert to spiked_amounts =  ' || vStandardSeqNexVal);
begin
INSERT INTO SPIKED_AMOUNTS (CREATE_DATE, FLAGS, LIMS_SEQUENCE, SEQUENCE_TYPE, SPIKE_VOLUME, STANDARD_SEQ, USER_NBR)
VALUES (SYSDATE, 'j..D......', p_schedule_seq, 'S', 1, vStandardSeqNexVal, 'CW');
exception
when others then
    TraceLog.Message('Error inserting into QC-56 spiked_amounts = '||SQLERRM(SQLCODE));
    TraceLog.ProcEnd(true);
end;
TraceLog.Message('p_schedule_seq =  ' || p_schedule_seq);
dbms_output.put_line('p_schedule_seq=  ' || p_schedule_seq);
TraceLog.Message('>>>>>>>>>>>>>>>>>>>>>>>>>>Inserted spiked amounts for the new QC-56 CALC spike for StdSeq ' || vStandardSeqNexVal);

end if; --if vGABTStdSeq is not null then


    end if; --if vCountSpike = 0 then
   end if; --if p_cmp = 'Tritium' then --only do this one time
  end if; --if vSampleType in ('GABTLC') then 
end if; --if vStandardAnalyteCount = 3 then  --shoud work for GABTLC

--end special handling GABTLC

if vSampleType = 'QC-56' then --sdk 2/10/2026
begin
select aux_data
into vGABTStdSeq
from aux_data 
where aux_data_format = 'PB1'
and aux_field = 1
and aux_data_type = 'B'
and aux_data_id = vBatchSeq;
exception
when no_data_found then
vGABTStdSeq := '';
when too_many_rows then
   -- p_error_message := 'Too many rows getting vGABTStdSeq';
    TraceLog.Message('Too many rows getting QC-56 aux data vGABTStdSeq');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vGABTStdSeq';
 TraceLog.Message('Other error getting QC-56 aux data vGABTStdSeq');
-- TraceLog.ProcEnd(true);
raise vGeneralException;
end;
TraceLog.Message('1749 vGABTStdSeq QC-56 aux data at very end =  ' || vGABTStdSeq);
end if; --if vSampleType = 'QC-56' then 

if (p_cmp != 'Tritium' and vGABTStdSeq is not null) then
--tritium CALC spike should already be inserted
begin
select standard_seq 
into vGABTCALCStdSeq
from spiked_amounts 
where lims_sequence = p_schedule_seq;
exception
when no_data_found then
vGABTCALCStdSeq := '';
when too_many_rows then
   -- p_error_message := 'Too many rows getting vGABTStdSeq';
    TraceLog.Message('Too many rows getting vGABTCALCStdSeq');
    --TraceLog.ProcEnd(true);
    raise vGeneralException;
when others then
--p_error_message := 'Other error getting vGABTStdSeq';
 TraceLog.Message('Other error getting vGABTCALCStdSeq');
-- TraceLog.ProcEnd(true);
raise vGeneralException;
end;

TraceLog.Message('1435 vGABTCALCStdSeq from Tritium insert and before GA/GB update =  ' || vGABTCALCStdSeq);
TraceLog.Message('1436 Going to SPECIAL PATCH Spiked_amounts for QC-56');
TraceLog.Message('vGABTStdSeq before patching = '||vGABTStdSeq); --appears in trace log

--spiked_amounts RECORDS DON'T EXIST YET TO UPDATE
--spiked_amounts record is already there after Tritium
TraceLog.Message('1441 Need to insert GA and GB decay corrected numbers into the QC-56 CALC spike');
TraceLog.Message('p_cmp = '||p_cmp); --appears in trace log
TraceLog.Message('1443 vDecayCorrectedNumber = '||vDecayCorrectedNumber); --appears in trace log

BEGIN
insert into standard_cmps (amount,CMP, SORT_ITEM,standard_seq, flags)
values (vDecayCorrectedNumber, p_cmp,1,vGABTStdSeq, '-'); --flags = dpm
exception
     when others then
       p_error_message := p_error_message || 'Unhandled Exception on insert to std_cmps.' || sqlerrm(sqlerrm);
       TraceLog.ProcEnd(true);
end;
end if; --if (p_cmp != 'Tritium' and vGABTStdSeq is not null) then

TraceLog.Message('1455 vStdSeq at very end ' || vStdSeq);

if vSampleType = 'QC-6' then 
        begin
        delete spiked_amounts where standard_seq = vStdSeq
        and lims_sequence = vPrepSchedule; --the old default one
        TraceLog.Message('At the very end...after GROSSBETA, QC-6,  We are done with and can now delete undecayed vStdSeq ' || vStdSeq); --the undecayed standard
        exception
        when others then
               p_error_message := p_error_message || 'Unhandled Exception Deleting QC-6 spiked_amounts in calc DCYSTD4a.' || sqlerrm(sqlerrm);
               --TraceLog.ProcEnd(true);
               raise vGeneralException;
        end;

 
else --all other QC
        

        
        begin
        delete spiked_amounts where standard_seq = vStdSeq
        and lims_sequence = p_schedule_seq; --the old default one
        TraceLog.Message('At the very end...after GROSSBETA. All other QC, We are done with and can now delete undecayed vStdSeq ' || vStdSeq);
        dbms_output.put_line('Deleted spike amounts for StdSeq ' || vStdSeq);
        exception
        when others then
               p_error_message := p_error_message || 'Unhandled Exception Deleting spiked_amounts in calc DCYSTD4a.' || sqlerrm(sqlerrm);
               --TraceLog.ProcEnd(true);
               raise vGeneralException;
        end;
        
        
        
end if;
end if; --if vCountCalcSpikes = 0 then  --then do all the rest, else exit

   TraceLog.Message('Calling Posting CALC RMLQA from DCYSTD4a');
    RMLQA(p_schedule_seq, p_schedule_type, p_schedule_id, p_cond_code, p_cmp, p_error_message); 
    
    
    if vSampleType = 'SAMPLE' then --probably not needed
   TraceLog.Message('Calling Posting CALC RMLNTLV1 from DCYSTD4a');
   -- RMLNTLV2(p_schedule_seq, p_schedule_type, p_schedule_id, p_cond_code, p_cmp, p_error_message); 
    --RMLNTLV4(p_schedule_seq, p_schedule_type, p_schedule_id, p_cond_code, p_cmp, p_error_message); 
    RMLNTLV1(p_schedule_seq, p_schedule_type, p_schedule_id, p_cond_code, p_cmp, p_error_message); 
    end if; --    if vSampleType = 'SAMPLE' then 



   -- End the procedure call in the TraceLog. Every possible return point should include this call or the  
   -- log will be malformed. Passing in "true" will add the execution time of this procedure to the log.
   TraceLog.ProcEnd(true);

-- Final procedureunexceptioned error catching
EXCEPTION
   WHEN EXIT_NOERROR THEN 
      p_error_message := null;
	  TraceLog.ProcEnd(true);
   WHEN EXIT_ERROR THEN  
      p_error_message := 'DCYSTD4a returning error: ' || p_error_message;
	  TraceLog.ErrorMsg(p_error_message);
	  TraceLog.ProcEnd(true);
   WHEN OTHERS THEN
      p_error_message := p_error_message ||    'Otherwise unexceptioned error IN DCYSTD4a.';
        TraceLog.ErrorMsg(p_error_message);
        TraceLog.ProcEnd(true);
      -- if unexceptioned error occurs, rollback
END;
/
exit;
