*-----------------------------------------------------------------------
* AD9510 Parameter Calculation Script
* Eric W. Anderson
* Copyright (C) 2011, Carnegie Mellon University. All rights reserved.
*
*  This is a GAMS optimization model.  It works well with the BARON
*  solver, and may be fine with others.  With a single target frequency
*  output (ft1, fout1, dout1), the model fits under the 10-variable demo
*  limit for BARON.  Otherwise, consider using a different solver or the
*  NEOS service.
*
*  This software is distributed under the terms of the GNU General Public
*  License (GPL), version 3 or later.
*
* THIS SOFTWARE IS PROVIDED BY CARNEGIE MELLON UNIVERSITY ``AS IS'' AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
* PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE FREEBSD PROJECT OR
* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
* PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
* LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*  
* The views and conclusions contained in the software and documentation
* are those of the authors and should not be interpreted as representing
* official policies, either expressed or implied, of Carnegie Mellon
* University.
*
*-----------------------------------------------------------------------
* System model:
*
* Reference: fr ---> [R Divider: /dr]  --> fpfd --> PFD
*                                                    ^
*                                                    |
*      VCXO: fn -+-> [N Divider: /dn]  --> fpfd  ----+
*                |
*                +-----> [Out divider: /dout1] -----> fout1
*                |                                        
*                +-----> [Out divider: /dout2]------> fout2
*                ...
*
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

$title AD9510 parameter calculation

parameters
	fr Reference frequency /170/
	ft1 Target frequency fout1 /200/
	ft2 Target frequency fout2 /125/
*-      VCO freqs for Crystek CVCO55CL-0600-0880
	vco_max VCO maximum frequency /880/
	vco_min VCO minimum frequency /600/
	
	
variables
	fn  VCXO frequency
	dn  VCXO divider ratio (N div)
	dr  Reference divider ratio (R div)
	fpfd PFD (phase and frequency detector) input frequency
	fout1 divided version of fn
	dout1 output divisor 1
	fout2 divided version of fn
	dout2 output divisor 2
	sse Sum of squared error
	p P component of N divider (see AD9510 data sheet pp 29-30)
	a A component of N divider (see AD9510 data sheet pp 29-30)
	b B component of N divider (see AD9510 data sheet pp 29-30)
	

Positive variable fn, dn, fpfd, fout1, fout2;
Integer variable dr, dout1, dout2;
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
dout1.lo = 1;
dout2.lo = 1;
dout1.up = 32;
dout2.up = 32;

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
	def_fout1 fout1 from VCO
	def_fout2 fout1 from VCO
	vco_lower VCO frequency > minimum
	vco_upper VCO frequency < maximum
	def_dn Definition of N divider
	error SS difference between ft1 and fn ;

ref_in..  fpfd =e= fr/dr ;
vcxo_in.. fpfd =e= fn/dn ;
def_fout1.. fout1 =e= fn/dout1;
def_fout2.. fout2 =e= fn/dout2;
vco_lower.. fn =g= vco_min;
vco_upper.. fn =l= vco_max;
* Fixed divide mode. 
def_dn..  dn =e= p*b;
error..   sse =e= (fout1-ft1)*(fout1-ft1) + (fout2-ft2)*(fout2-ft2) ;

Model ad9510 /all/ ;

solve ad9510 using minlp minimizing sse ;

display fr, ft1, fout1.l, ft2, fout2.l, fn.l, fpfd.l;
display dr.l, dn.l, dout1.l, dout2.l ;
display p.l, a.l, b.l;