*! Version 1.0.1   2601 rjs/cfb 
* Multivariate Ljung-Box statistic (see p. 22 in Johansen (1995)).
* Programmed by Richard Sperling on 1/13/01
* Verified on 1/13/01 using Danish data in section 2.4.1
* 1.0.1: 2601 corrected for if touse

program define wntstmvq, rclass
	version 6
	syntax varlist(ts) [if] [in] [,Lags(integer -1) Varlags(integer 0)]
	marksample touse
	_ts timevar, sort
	markout `touse' `timevar'
	tsreport if `touse', report
	if r(N_gaps) {
		di in red "sample may not contain gaps"
		exit
	}
	tempname C0 C0inv LB mattmp
	local count: word count `varlist'
	if `count'<2 {
		di in red "at least two variables must be specified"
		exit
		}
	local count1 = `count'+1
*060102: added if `touse'
	qui mat accum `C0' = `varlist' if `touse', noc
	local nobs=r(N)
	mat `C0' = 1/`nobs' * `C0'
	mat `C0inv' = syminv(`C0')
* if no lag option provided, use formula from ac for max lag
	if(`lags'<1) {
		local lags = min(`nobs'/2 - 2 ,40)
		}
* Initialize Ljung-Box statistic (LB)
	scalar `LB' = 0
	local i 1
	while `i' <= `lags' {
		local lagvlst `varlist'
		local j 1
		while `j'<=`count' {
			local vv: word `j' of `varlist'
			local lagvlst  " `lagvlst' L`i'.`vv'"
			local j = `j'+1
			}
*060102: added if `touse'
		qui mat accum `mattmp' = `lagvlst' if `touse', noc
  		mat `mattmp' = 1/`nobs' * `mattmp'[1..`count', `count1'...]
		mat `mattmp' = `mattmp' * `C0inv' * (`mattmp')' * `C0inv'
		scalar `LB' = `LB' + 1/(`nobs' - `i') * trace(`mattmp')
		local i = `i' + 1
	}

	return scalar stat = `nobs' * (`nobs' + 2) * `LB'
	return scalar df = `count'^2*(`lags'-`varlags')
	return scalar p = chiprob(return(df),return(stat))
	return scalar k = `count'
	return scalar s = `lags'
	return scalar nobs = `nobs'
	di _n in gr "Multivariate Ljung-Box statistic (`count' variables, `lags' lags): " /*
	*/ in ye %10.4f return(stat)
	di in gr "Prob > chi2(" in ye return(df) in gr ") = " in ye %6.4f return(p)

end
exit
	
* The asymptotic distribution is chi-square with p^2 * (s - k) df, where:
* p = dimension of VAR model (here p = 4)
* s = # of lags to use in calculating LB (here s = 13)
* k = # of lags in original VAR model (here k = 2)
