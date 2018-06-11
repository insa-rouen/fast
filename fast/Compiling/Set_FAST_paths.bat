
IF "%COMPUTERNAME%"=="BJONKMAN-23080S" GOTO BJONKMAN-23080S
IF "%COMPUTERNAME%"=="BJONKMAN-20916S" GOTO BJONKMAN-20916S
:: IF "%COMPUTERNAME%"=="MBUHL-20665S" GOTO MBUHL-20665S

REM --------------------------------------------------------------------------------------------------------------------------------
REM These paths are for Bonnie Jonkman; other users should modify their own paths as necessary.

:BJONKMAN-23080S
ECHO Setting paths for Bonnie Jonkman.

SET Crunch=C:\Users\bjonkman\Documents\DATA\DesignCodes\postprocessors\Crunch\SVNdirectory\trunk\crunch_win32.exe

SET REG_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\miscellaneous\FAST_Registry\source
SET Registry=%REG_Loc%\..\bin\Registry_Win32.exe

SET FAST_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\FAST\SVNdirectory\branches\BJonkman\Source

SET NWTC_Lib_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\miscellaneous\nwtc_subs\gitHub\source
SET NETLIB_Loc=%NWTC_Lib_Loc%
SET ED_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\ElastoDyn\gitHub\trunk\source\ElastoDyn
SET BD_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\BeamDyn\GitforSVN\trunk\source
SET SrvD_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\ServoDyn\gitHub\trunk\source\ServoDyn
SET TMD_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\ServoDyn\gitHub\trunk\source\TMD

SET AD_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\AeroDyn\gitHub\Source\dependencies\AeroDyn
SET BEMT_Loc=%AD_Loc%\..\BEMT
SET UA_Loc=%AD_Loc%\..\UnsteadyAero
SET AFI_Loc=%AD_Loc%\..\Airfoil_Info


SET AD14_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\AeroDyn14\gitHub\Source
SET DWM_Loc=%AD14_Loc%\DWM

SET IfW_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\InflowWind\gitHub\Source
SET IfW_Reg_Loc=%IfW_Loc%\Registry

SET OpFM_Loc=%FAST_Loc%\dependencies\OpenFOAM
SET Orca_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\OrcaFlex\gitHub\Source

SET SD_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\SubDyn\SVNdirectory\trunk\Source

SET HD_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\HydroDyn\gitHub\Source
SET HD_Reg_Loc=%HD_Loc%\RegistryFiles

SET MAP_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\MAP\SVNdirectory\trunk
SET MAP_Loc_R=%MAP_Loc%\registry
SET MAP_Loc_F=%MAP_Loc%\fortran_driver
SET MAP_DLL=%MAP_Loc%\bin\MAP_Win32.dll
SET MAP_DLL64=%MAP_Loc%\bin\MAP_x64.dll
SET MAP_Include_Lib=%MAP_Loc%\bin\MAP_Win32.lib

SET MD_LOC=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\MoorDyn\GitforSVN\trunk\source
rem SET MD_LOC=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\MoorDyn\GitforSVN\branches\bonnie_MiscVars\source

SET FEAM_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\FEAMooring\gitHub\source

SET IceF_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\IceFloe\gitHub\source\interfaces\FAST
SET IceF_RanLux_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\IceFloe\gitHub\source\ranlux
SET IceF_Loc2=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\IceFloe\gitHub\source\IceFloe

SET IceD_Loc=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\IceDyn\gitHub\source


GOTO End
REM --------------------------------------------------------------------------------------------------------------------------------
:BJONKMAN-20916S

SET REG_Loc=C:\Users\bjonkman\Documents\CAETools\FAST_Registry
SET Registry=%REG_Loc%\registry.exe

SET FAST_Loc=C:\Users\bjonkman\Documents\CAETools\FASTv8\Source


SET ED_Loc=%FAST_Loc%
SET SrvD_Loc=%FAST_Loc%

SET HD_Loc=C:\Users\bjonkman\Documents\CAETools\HydroDyn\Source
SET HD_Reg_Loc=%HD_Loc%\RegistryFiles

SET TMD_Loc=C:\Users\bjonkman\Documents\CAETools\TMD\Source
:: SET MAP_DLL=C:\Users\bjonkman\Documents\DATA\DesignCodes\simulators\MAP\SVNdirectory\trunk\executable\MAP_win32.dll


REM --------------------------------------------------------------------------------------------------------------------------------
:End
