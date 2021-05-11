# FAST installation
# 
# Author: Hao Bai (hao.bai@insa-rouen.fr)
# Comments: Tested and valid in Ubuntu 20.04.02 LTS
#



# Step 1:
# Please make sure that you have internet access and you have right to connect GitHub
sudo apt install gfortran liblapacke-dev build-essential
mkdir ~/Eolien
git clone git@github.com:insa-rouen/fast.git ~/Eolien/FAST
chmod 777 ~/Eolien/FAST/fast.sh
chmod 777 ~/Eolien/FAST/turbsim.sh
cd ~/Eolien/FAST
ln -s make/make.glin64 make.inc
make
mv ~/Eolien/FAST/DISCON_glin64.so ~/Eolien/Parameters/NREL_5MW_Onshore/WT/DISCON_dar64.so
chmod 777 ~/Eolien/Parameters/NREL_5MW_Onshore/WT/DISCON_dar64.so

# Step 2:
# Please add the following codes (from line 28 to line 35) to ~/.bashrc file
export PATH=$PATH:"${HOME}/Eolien/FAST/"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"${HOME}/Eolien/FAST/"
export PYTHONPATH=$PYTHONPATH:"${HOME}/Eolien/Parameters/Python/site-packages"
alias fast='~/Eolien/FAST/fast.sh'
alias fa=fast
alias iecwind='~/Eolien/FAST/IECWind_glin64 ./IEC.IPT'
alias turbsim='~/Eolien/FAST/turbsim.sh'
alias crunch='~/Eolien/FAST/Crunch_glin64'

# Step 3: Testing
source ~/.bashrc
cd ~/Eolien/Parameters/NREL_5MW_Onshore/Wind/DLC1.1
turbsim NTM_3mps.inp
cd ~/Eolien/Parameters/NREL_5MW_Onshore
fast DLC1.1_NTM_3mps.fst