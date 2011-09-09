*-----------------------------------------------------------------------
* AD9510 Parameter Calculation Script
* Eric W. Anderson
* Copyright (C) 2011, Carnegie Mellon University. All rights reserved.
*
*  This is a GAMS optimization model.  It works well with the BARON
*  solver, and may be fine with others.  With a single target frequency
*  output (ft1, fout1, dout1), the model fits under the 10-variable demo
*  limit for BARON.  Otherwise, consider using a different solver or the
*  NEOS service. http://www.neos-server.org/neos/solvers/go:BARON/GAMS.html
*
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU General Public License as published by
*  the Free Software Foundation, either version 3 of the License, or
*  (at your option) any later version.
*
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU General Public License for more details.
*
*  You should have received a copy of the GNU General Public License
*  along with this program.  If not, see <http://www.gnu.org/licenses/>.
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
	dm_mode Use DM (Dual Modulus mode) 0=no (FD mode)  1=yes.
	p_dm P component of N divider (DM mode) (see AD9510 data sheet pp 29-30)
	p_fd P component of N divider (FD mode) (see AD9510 data sheet pp 29-30)
	p_exp Exponent determining P in DM mode
	p_div_dm Actual dividing value of prescaler.
	p_div_fd Actual dividing value of prescaler. 
	a A component of N divider (see AD9510 data sheet pp 29-30)
	b B component of N divider (see AD9510 data sheet pp 29-30)
	b_byass Configure bypass of b (effectively b=1) (p 30)
	b_eff Effective value of B

	

Positive variable p_dm, fn, dn, p_div_dm, p_div_fd, fpfd, fout1, fout2, b_eff;
Integer variable dr, dout1, dout2;
Integer variable dm_mode, p_fd, p_exp, a, b, b_bypass;

* Bool
dm_mode.lo = 0;
dm_mode.up = 1;

* Bool
b_bypass.lo = 0;
b_bypass.up = 1;

* From AD9510 Data sheet, page 29
dr.lo = 1.0;
dr.up = 16383;

* From AD9510 Data sheet, pages 29 and 30
a.lo = 0;
a.up = (2**6)-1;


* With no B bypass: (Bypass adds 1 as another option (but 2 is still out))
b.lo = 3;
b.up = 8191;

* Including bypass
b_eff.lo = 1;
b_eff.up = 8191;

* From AD9510 Data sheet Table 14, page 30
* Fixed divisor mode only!
p_fd.lo = 1;
p_fd.up = 3;

* From AD9510 Data sheet Table 14, page 30
* Dual Modulus mode
* P = {2,4,8,16,32} = 2^p_exp: p_exp = {1,2,3,4,5}
p_exp.lo = 1;
p_exp.up = 5;

* Guessing: A is 6 bits (0 -- 2^6-1)
a.lo = 0;
a.up = 63;

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
	def_b_eff Effective value of B (depends on bypass)
	def_p_dm  Definition of P in dual-modulus prescale mode
	def_p_div_fd Definition of p_div (the actual divison ratio) in FD mode
	def_p_div_dm Definition of p_div (the actual divison ratio) in DM mode
	def_dn Definition of N divider (fixed-divide OR dual-modulus mode)
	error SS difference between ft1 and fn ;

ref_in..  fpfd =e= fr/dr ;
vcxo_in.. fpfd =e= fn/dn ;
def_fout1.. fout1 =e= fn/dout1;
def_fout2.. fout2 =e= fn/dout2;
vco_lower.. fn =g= vco_min;
vco_upper.. fn =l= vco_max;
def_p_div_fd.. p_div_fd =e= p_fd;
def_p_dm.. p_dm =e= 2**p_exp;
def_p_div_dm.. p_div_dm =e= p_dm/(p_dm+1) ;

* Note: This says dn must be a convex combination of the FD and DM
* options.  Since dm_mode is a 0-1 variable, this effectively means
* "if dm_mode A else B"
def_dn.. dn =e=
	 ((dm_mode) *((p_div_dm*b_eff)+ a)) +
	 ((1-dm_mode) * (p_div_fd*b_eff)) ;

*Same trick
def_b_eff.. b_eff =e=
	    (b_bypass * 1) +
	    ((1-b_bypass) * b) ;
	    
error..   sse =e= (fout1-ft1)*(fout1-ft1) + (fout2-ft2)*(fout2-ft2) ;

Model ad9510 /all/ ;

solve ad9510 using minlp minimizing sse ;

display fr, ft1, fout1.l, ft2, fout2.l, fn.l, fpfd.l;
display dr.l, dn.l, dout1.l, dout2.l ;
display dm_mode.l, p_fd.l, p_div_fd.l, p_dm.l, p_div_dm.l, p_fd.l;
display a.l, b_bypass.l, b.l, b_eff.l;