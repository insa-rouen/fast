function weibullTable = create_weibull_table( Fatigue )

   weibullTable = DataTable();
   
   
   weibullTable{1,1} = 'Vin:';
   weibullTable{1,2} = Fatigue.WSin;
   weibullTable{2,1} = 'Vout:';
   weibullTable{2,2} = Fatigue.WSout;
   weibullTable{3,1} = 'Vmax:';
   weibullTable{3,2} = Fatigue.WSmax;
   weibullTable{4,1} = 'Weibull mean wind speed:';
   weibullTable{4,2} = Fatigue.weibullMeanWS;
   weibullTable{5,1} = 'Weibull standard deviation:';
   weibullTable{5,2} = Fatigue.weibullStdDev;
   weibullTable{6,1} = 'Weibull shape factor:';
   weibullTable{6,2} = Fatigue.weibullShapeFactor;
   weibullTable{7,1} = 'Weibull scale factor:';
   weibullTable{7,2} = Fatigue.weibullScaleFactor;
end