$title AD9510 parameter calculation

*------------------------------------------------------------------------	
* Reference: fr ---> [R Divider: /dr]  --> fpfd --> PFD
*                                                    ^
*                                                    |
*      VCXO: fn -+-> [N Divider: /dn]  --> fpfd  ----+
*                |
*                +-----> [Out dividers: /dout] ------> fout
*
* All outputs are fractions (power of 2) of VCO frequency f_n
* Reference input is frequency f_r.
* f_pfd is the phase detector frequency.
*
* (f_r / d_r) = f_pfd = (f_n / d_n)
*
* Free variables are f_fpd, f_n, d_r, d_n.  f_pfd and f_n
* are continuous with simple bounds.  Dividers (d_n, d_r), are
* discrete and complicated.       
*------------------------------------------------------------------------

parameters
	fr Reference frequency /170/
	ft Target frequency /200/
	vco_max VCO maximum frequency /880/
	vco_min VCO minimum frequency /600/

	
variables
	fn  VCXO frequency
	dn  VCXO divider ratio (N div)
	dr  Reference divider ratio (R div)
	fpfd PFD (phase and frequency detector) input frequency
	fout divided version of fn
	dout output divisor
	se Squared error
	p P component of N divider (see AD9510 data sheet pp 29-30)
	a A component of N divider (see AD9510 data sheet pp 29-30)
	b B component of N divider (see AD9510 data sheet pp 29-30)
	

Positive variable fn, dn, fpfd, fout;
Integer variable dr, dout;
Integer variable p, a, b;

* From AD9510 Data sheet, page 29
dr.lo = 1.0;
dr.up = 16383;

* With no B bypass: (Bypass adds 1 as another option (but 2 is still out))
b.lo = 3;
b.up = 8191;

* From AD9510 Data sheet Table 14, page 30
* Fixed divisor mode only!
p.lo = 1;
p.up = 3;

* Guessing: A is 6 bits
a.lo = 0;
a.up = 2**6-1;

* From AD9510 Data sheet, Figure 33
dout.lo = 1;
dout.up = 32;

dn.lo = 1.0;

* From AD9510 Data sheet, Table 1
fpfd.up = 150;

* Made up!
fpfd.lo = 10; 
* From AD9510 data sheet, Table 2
fn.up = 1600;

equations
	ref_in Reference frequency to PFD
	vcxo_in VCO to PFD
	def_fout fout from VCO
	vco_lower VCO frequency > minimum
	vco_upper VCO frequency < maximum
	def_dn Definition of N divider
	error SS difference between ft and fn ;

ref_in..  fpfd =e= fr/dr ;
vcxo_in.. fpfd =e= fn/dn ;
def_fout.. fout =e= fn/dout;
vco_lower.. fn =g= vco_min;
vco_upper.. fn =l= vco_max;
* Fixed divide mode. 
def_dn..  dn =e= p*b;
error..   se =e= (fout-ft)*(fout-ft) ;

Model ad9510 /all/ ;

solve ad9510 using minlp minimizing se ;

display fr, ft, fout.l, fn.l, fpfd.l;
display dr.l, dn.l, dout.l ;
display p.l, a.l, b.l;