function lifetimeTable = create_lifetime_header_table(FileInfo, Fatigue)

   lifetimeTable = DataTable();
   
   lifetimeTable{1,1} =  'Total number of samples';
   lifetimeTable{1,2} = sum(FileInfo.nSamples(:));
   lifetimeTable{2,1} = 'Equivalent load frequency:';
   lifetimeTable{2,2} = sprintf( '%g Hz', Fatigue.EquivalentFrequency);
   lifetimeTable{3,1} = 'Total number of equivalent cycles:';
   lifetimeTable{3,2} = Fatigue.lifetimeEquivalentCycles;
   lifetimeTable{3,3} = Fatigue.RFPerStr;
   
end