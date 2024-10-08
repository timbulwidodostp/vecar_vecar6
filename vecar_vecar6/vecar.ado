*! version 1.1.14  CFBaum  2531 
* 1.1.14 2531 wntstmvq in sample
* 1.1.13 2527 predict in sample
* 1.1.12 2416 sample header
* 1.1.11 1620 corr 80-byte bug
* 1.1.10 1424 add uncorr option
* 1.1.9  1422 add saving and using logic
* 1.1.8  1422 prevent maxlag=0, add ll(0) code 
* 1.1.7  1420 add AIC code
* 1.1.6  1418 deal with ts operators via tsrevar
* 1.1.5  1311 from mvreg and wntstmvq, incorp omninorm
* version 3.3.8  13oct2000
program define vecar, eclass byable(recall)
	version 7

	local myopt "Exog(varlist ts) Level(integer $S_level) Table noHeader COV DFK noConstant"
	qui tsset /* error if not set as time series */

	tempname sigma tsig ft
	tempname rcv
	if !replay() {
		syntax varlist(min=2 ts) [if] [in]  ,Maxlag(integer) [ `myopt' Saving(string) Using(string) uncorr]
		if `maxlag' < 1 {
			di in r "maxlag must be at least 1."
			error 198
			}
		local eqnames `varlist'
		local neq : word count `eqnames'
		local eqnames `varlist'
		local varlist `exog'
		local dfk `dfk'
		local dev "dev"
		if "`constant'" == "noconstant" { local dev "" }
		local uncorr `uncorr'
		local i 1
		while (`i'<=`neq') {
			local eqn : word `i' of `eqnames'
			local varlist `varlist' L(1/`maxlag').`eqn'
			local i = `i' + 1
		}
		local i 1
		while (`i'<=`neq') {
			local eqn : word `i' of `eqnames'
			eq `eqn' `varlist'
			local i = `i' + 1
		}
		tempvar touse
		mark `touse' `if' `in' 
		markout `touse' `eqnames' `varlist'
		qui tsset
		local tv `r(timevar)'
		qui summ `tv' if `touse', meanonly
		local fmt : format `tv'
		local tmin = trim(string(r(min), "`fmt'"))
		local tmax = trim(string(r(max), "`fmt'"))

		tempname ee xx xy yy bb xxi cxxi b idfe ss
		qui mat accum `ee' = `eqnames' `varlist' /*
			*/ if `touse', `constant'
		local nobs = r(N)
		local neqp1 = `neq' + 1
		mat `xx' = `ee'[`neqp1'...,`neqp1'...]
		mat `xy' = `ee'[`neqp1'...,1..`neq']
		mat `yy' = `ee'[1..`neq',1..`neq']
		mat drop `ee'
		mat `xxi' = syminv(`xx')
		mat `bb' = `xy'' * `xxi'
		mat `rcv' = `yy' - `bb'*`xx'*`bb''

		local dfe = `nobs' - rowsof(`xx')
		scalar `idfe' = 1/`dfe'
		mat `rcv' = `rcv' * `idfe'
		mat `cxxi' = `rcv' # `xxi'
		local i 1
		while (`i' <= `neq') {
			mat `xx' = `bb'[`i',1...]
			local eqn : word `i' of `eqnames'
			mat coleq `xx' = `eqn'
			mat `b' = nullmat(`b') , `xx'
			local t : display string(sqrt(`rcv'[`i',`i']), "%9.0g")
			local sd "`sd' `t'"
			qui summ `eqn' if `touse' [`weight'`exp']
			if ("`constant'"=="") {
				local t = 1 - `rcv'[`i',`i']*`dfe' /*
					     */ /(r(N)-1)/r(Var)
			}
			else local t = 1 - `rcv'[`i',`i']*`dfe'/`yy'[`i',`i']
			local t : display string(`t', "%6.4f") 
			local r2 "`r2' `t'"
			local i = `i' + 1
		}
		est post `b' `cxxi', dof(`dfe') esample(`touse')
* get names stripped of ts operators
		tsrevar `eqnames',list
* 1620: correct 80-byte bug
		local eqnames2  "`r(varlist)'"
		local i 1
		while (`i' <= `neq') {
			local eqn : word `i' of `eqnames2'
			qui test [`eqn']
			local t : display string(r(F), "%9.0g") 
			local f "`f' `t'"
			local t : display /*
				*/ string(fprob(r(df),r(df_r),r(F)), "%6.4f")
			local prv "`prv' `t'"
			local i = `i' + 1
		}

		est local r2 "`r2'"
		est local p_F "`prv'"
		est local rmse "`sd'"
		est local F "`f'"
		est local eqnames "`eqnames'"
		est local depvar `e(eqnames)'
		est scalar k  = colsof(`bb')
		est scalar df_r = `dfe'
		est scalar maxlag = `maxlag'
		est scalar k_eq = `neq'
		est scalar N    = `nobs'
		est local predict "reg3_p"
		est local cmd "vecar"

* create cov matrix of residuals 
* default: divide by T, but dfk option implies division by T-k 
		if "`dfk'"=="" {
			mat `rcv' = float((e(N)-e(k))/e(N)) * `rcv'
			}
		else {
			local based "-k"
		}
		est matrix Sigma `rcv'
* save log det Sigma for VAR
		local ldet = log(det(e(Sigma)))
		est scalar ll = `ldet'
* calc equivalent for meanonly model (do not use dev if model lacks constant)
		qui mat accum `ss' = `e(eqnames)' if e(sample), `dev' noc
		mat `ss' = `ss'/`e(N)'
		local ldet0 = log(det(`ss'))
		est scalar ll0 = `ldet0'
		mat drop `xx' `yy' `xy' `bb'
	}
	else {
		if ("`e(cmd)'"!="vecar") { error 301 }
		if _by() { error 190 }
		syntax [, `myopt']
	}
	if ("`header'"=="") {
		local i 1
		di
		di in smcl as res "Vector Autoregression for lags 1-`e(maxlag)'
		di in smcl "{txt}Sample: {res}`tmin' {txt}to {res}`tmax'"
		di 
		if "`exog'" !="" { 
			di "Exogenous variables : `exog'"
			di
			}
		di in gr "Equation            T      k        RMSE    " _quote "R-sq" _quote "          F        P"
		di in smcl in gr "{hline 70}"
		while (`i'<=e(k_eq)) {
			local myword : word `i' of `e(eqnames)'
			local sd : word `i' of `e(rmse)'
			local r2 : word `i' of `e(r2)'
			local f  : word `i' of `e(F)'
			local pv : word `i' of `e(p_F)'
			local parms "`e(k)'"
			local nobs e(N)     
			local myword = abbrev("`myword'",12)
			di in ye "`myword'" _col(14) %8.0f `nobs' /*
				*/ %7.0f `parms' /*
				*/ "   " %9.0g `sd' %10.4f `r2' "  " /*
				*/ %9.0g `f' %9.4f `pv'
			local i = `i' + 1
		}
	}
	if ("`table'"!="") {
		di
		est di, level(`level')
	}

* VAR: block F tests on each eqn (joint signif of each variable in the eqn) 
		mat def `ft' = J(e(k_eq)*e(k_eq),2,0)
		local i 1
		local k 1
		local rownam " "
		while (`i'<=e(k_eq)) {
* access eqnames2 to look up equation name
				local myword : word `i' of `eqnames2'
				local vl`k' " "
				local j 1
					while (`j'<=e(k_eq)) {
					local myword2 : word `j' of `e(eqnames)'
					local m 1
					while (`m'<=`e(maxlag)') {
						local vl`k' `vl`k'' [`myword']L`m'.`myword2'
						local m = `m'+1
						}
					local rownam  `rownam' `myword':`myword2'
					local j = `j'+1
					local k = `k'+1
					}
				local i = `i'+1
				}
		local i 1
		while(`i'<`k') {
				qui test  `vl`i''
				mat `ft'[`i',1]=r(F)
				mat `ft'[`i',2]=r(p)
				local i = `i'+1
				}
		di
		di "Block F-tests with `r(df)' and `r(df_r)' d.f."
		matrix rownames `ft' = `rownam'
		matrix colnames `ft' = F p-value
		di in smcl in gr "{hline 32}"
		mat list `ft', nohead format(%9.4f)	
	
		if "`saving'" != "" {
			if (length("`saving'")>4) { 
				di in red "saving() name too long"
				exit 198
			}
			capt macro drop LRTS`saving'
			global LRTS`saving' "`e(cmd)' `e(N)' `e(ll)' `e(k_eq)' `e(maxlag)' `e(k)'"

		}	
		
		if "`using'"!= "" {
			if (length("`using'")>4) { 
				di in red "using() name too long"
				exit 198
			}
		local user `using'
		local name LRTS`user'
		local touse $`name'
		if "`touse'"=="" {
			di in red _n "model `user' not found"
			exit 302
		}
		tokenize `touse'
		local bmod `1'
		local bobs `2'
		local bll  `3'
		local bkeq `4'
		local bmxl `5'
		local bk   `6'
		if "`bmod'" != e(cmd)  {
			di in red _n "cannot compare `bmod' and `e(cmd)' estimates"
			exit 402
		}
		if `bkeq' != e(k_eq)  {
			di in red _n "cannot compare vecar estimates from different systems"
			exit 402
		}
		if  `bmxl' <= e(maxlag) {
			di in red _n "cannot compare vecar estimates of `bmxl' vs. `e(maxlag)' lags"
			exit 402
		}
		if `bobs' != e(N) { 
			di in blu _n "Warning:  observations differ:  `bobs' vs. `e(N)'"
			}
		di _n "Log det (`bmxl' lags) = " in ye %9.4f `bll'
		di    "Log det (`e(maxlag)' lags) = " in ye %9.4f `e(ll)' 
		local diff = `e(ll)' - `bll'
* correction per Sims, 1980 Econometrica, p.17 (disable with uncorr)
		local lrmult = `e(N)'
		if "`uncorr'" =="" { 
			local lrmult = `lrmult' - `bk'
			local kadj "(T-k)"
			}
		local lrt  = `lrmult' * `diff'
		local lrdf = `e(k_eq)'*(`bk'-`e(k)')
		di _n "LR Test `kadj' = " in ye %9.4f `lrt' in gr " Prob > Chi2(`lrdf') = " /* 
		*/ in ye %6.4f chiprob(`lrdf',`lrt')
		}
	
		if ("`cov'"!="") {
		di
		di in gr "Covariance matrix of residuals (based on T`based'):"
		mat list e(Sigma), nohead /* format(%9.4f) */
		di _n "Log det (`e(maxlag)' lags) = " in ye %9.4f `e(ll)' 
		di    "Log det (0 lags) = " in ye %9.4f `e(ll0)' 
		local diff = `e(ll0)' - `e(ll)'
* correction per Sims, 1980 Econometrica, p.17 (disable with uncorr)
		local lrmult = `e(N)'
		if "`uncorr'" =="" { 
			local lrmult = `lrmult' - `e(k)'
			local kadj "(T-k)"
			}
		local lrt  = `lrmult' * `diff'
		local lrdf = `e(k_eq)'^2*`e(maxlag)'
		di _n "LR Test `kadj' = " in ye %9.4f `lrt' in gr " Prob > Chi2(`lrdf') = " /* 
		*/ in ye %6.4f chiprob(`lrdf',`lrt')
* RSperling 1420; do not reverse sign e(ll)
		local AIC = `e(ll)' + 2 * `e(maxlag)' * `e(k_eq)'^2 / `e(N)'
		local SC = `e(ll)' + log(`e(N)') / `e(N)' * `e(maxlag)' * `e(k_eq)'^2
		local HQ = `e(ll)' + 2 * log(log(`e(N)')) / `e(N)' * `e(maxlag)' * `e(k_eq)'^2
		di in gr _n "Order selection criteria:" _n
		di in gr "AIC = " in ye %7.4f `AIC'
		di in gr "SC  = " in ye %7.4f `SC'
		di in gr "HQ  = " in ye %7.4f `HQ'
		est scalar AIC = `AIC'
		est scalar SC = `SC'
		est scalar HQ = `HQ'
*
		local vl
		forv i=1/`e(k_eq)' {
			tempvar r`i'
* 2527: pred only in sample
			qui predict `r`i'' if e(sample),r eq(#`i')
			local vl `vl' `r`i''
			}
* 2531: test over sample
		wntstmvq `vl' if e(sample),varlags(`e(maxlag)')
		mat `sigma' = corr(e(Sigma))
		mat `sigma' = `sigma' * `sigma' '
		local tsig = (trace(`sigma') - e(k_eq))*e(N)/2
		local df = e(k_eq)*(e(k_eq)-1)/2
		di
		di in gr "Breusch-Pagan test of independence: chi2(`df') = " /*
		*/ in ye %9.3f `tsig' in gr ", Pr = " %6.4f /* 
		*/ in ye chiprob(`df',`tsig')

		est scalar df_chi2 = `df'
		est scalar chi2 = `tsig'

		/* Double saves */
		global S_3 "`e(df_chi2)'"
		global S_4 "`e(chi2)'"
	
		omninorm `vl' 
	}
end
exit
