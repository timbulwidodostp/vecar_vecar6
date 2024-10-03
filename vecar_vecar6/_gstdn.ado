*! hacked from _gstd version 2.1.1  25jun2000  cfb 26mar2001
program define _gstdn
        version 6
        syntax newvarname =/exp [if] [in] [, Mean(real 0) Std(real 1) /*
                        */ BY(string)]
        if `"`by'"' != "" {
                _egennoby std() `"`by'"'
                /* NOTREACHED */
        }


        quietly {
                gen `typlist' `varlist' = `exp' `in' `if'
                sum `varlist' `if' `in'
                local nadj = r(Var)*(r(N)-1)/r(N)
                replace `varlist' = /*
                         */ ((`varlist'-r(mean))/sqrt(`nadj'))*(`std') /*
                         */ + (`mean') 
                label var `varlist' "Standardized values of `exp'"
        }
end
exit
