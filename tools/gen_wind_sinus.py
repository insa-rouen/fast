#!/usr/bin/env python
# -*- coding: utf-8 -*-

from math import sin,pi
#import sys, getopt

#myopts, args = getopt.getopt(sys.argv[1:],"f:")

#for o, a in myopts:
#    if o == '-f':
#        frequency=float(a)
#    else:
frequency=0.2475

windir=0.0
winvspeed=0.0
hshear=0.2
vshear=0.0
linvshear=0.0
gustspeed=0.0

vmax=12.0
nppp=30
tmax=121.0
aramp=10.0
zramp=5.0

dt=1.0/(frequency*nppp)
nstep=int(tmax/dt)+1

print("! Wind sinusoidal")
print("! Time	Wind	Wind	Vert.	Horiz.	Vert.	LinV	Gust")
print("!		Speed	Dir	    Speed	Shear	Shear	Shear	Speed")

for it in range(0,nstep):

    t=it*dt

    if(t<zramp):

        winspeed=0.0

    else:

        if(t<zramp+aramp):

            winspeed=sin((t-zramp)/aramp*pi/2.0)*(vmax*sin(2.0*pi*frequency*t)+vmax)/2.0

        else:

            winspeed=(vmax*sin(2.0*pi*frequency*t)+vmax)/2.0

    print("{:.2f}\t{:.2f}\t{:.2f}\t{:.2f}\t{:.2f}\t{:.2f}\t{:.2f}\t{:.2f}".format(t,winspeed,windir,winvspeed,hshear,vshear,linvshear,gustspeed))
