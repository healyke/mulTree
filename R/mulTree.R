##########################
#Run MCMCglmm on a 'mulTree.data' object
##########################
#Running a MCMCglmm model on a list of phylogenies and the data stored in a 'mulTree.data' object. The results can be written out of R environment as individual models.
#v0.1.4
#Update: added convergence conditions
#Update: typos and added warn option
#Update: fixed timing management
##########################
#SYNTAX :
#<mulTree.data> a 'mulTree.data' object obtained from as.mulTree.data function
#<formula> an object of class 'formula'
#<chains> the number of independent chains for the mcmc
#<parameters> a vector of three elements to use as parameters for the mcmc. Should be respectively Number of generations, sampling and burnin.
#<priors> a series of priors to use for the mcmc (default=NULL is using the default parameters from MCMCglmm function)
#<...> any additional argument to be passed to MCMCglmm() function
#<convergence> a numerical value for assessing chain convergence (default=1.1)
#<ESS> a numerical value for assessing the effective sample size (default=1000)
#<verbose> whether to be verbose or not (default=FALSE)
#<output> any optional string of characters that will be used as chain name for the models output (default=FALSE)
#<warn> whether to print the warning messages from the MCMCglmm function (default=TRUE)
##########################
#----
#guillert(at)tcd.ie & healyke(at)tcd.ie - 13/08/2014
##########################
#Requirements:
#-R 3
#-R package "ape"
#-R package "caper"
#-R package "MCMCglmm"
#-R package "coda"
##########################


mulTree<-function(mulTree.data, formula, parameters, chains=2, priors=NULL, ..., convergence=1.1, ESS=1000, verbose=FALSE, output=TRUE, warn=TRUE)
{   #warning("ouput option doesn't accept 'FALSE' yet (change the return format)")
    #stop("IN DEVELOPEMENT")
#HEADER
    #libraries
    require(ape)
    require(caper)
    require(coda)
    require(MCMCglmm)
    #timer(start)
    start.time <- Sys.time()

#DATA
    #mulTree.data
    if(class(mulTree.data) != 'mulTree') {
        stop(as.character(substitute(mulTree.data))," is not a \"mulTree\" object.\nUse as.mulTree.data() function.", call.=FALSE)
    } else {
        if(length(mulTree.data) != 3) {
            stop(as.character(substitute(mulTree.data))," is not a \"mulTree\" object.\nUse as.mulTree.data() function.", call.=FALSE)
        } else {
            if(class(mulTree.data[[1]]) != 'multiPhylo') {
                stop(as.character(substitute(mulTree.data))," is not a \"mulTree\" object.\nUse as.mulTree.data() function.", call.=FALSE)
            } else {
                if(class(mulTree.data[[2]]) != 'data.frame') {
                    stop(as.character(substitute(mulTree.data))," is not a \"mulTree\" object.\nUse as.mulTree.data() function.", call.=FALSE)
                }
            }
        }
    }

    #formula
    if(class(formula) != 'formula') {
        stop(as.character(substitute(formula))," is not a \"formula\" object.", call.=FALSE)
    }

    #chains
    if(class(chains) != 'numeric') {
        stop("\"chains\" must be numeric.", call.=FALSE) 
    } else {
        if(length(chains) != 1) {
            stop("\"chains\" must be a single value.", call.=FALSE) 
        } else {
            if(chains == 1) {
                multiple.chains=FALSE
                warning("Only one chain has been called:\nconvergence test can't be performed.", call.=FALSE)
            } else {
                multiple.chains=TRUE
            }
        }
    }

    #parameters
    if(class(parameters) != 'numeric') {
        stop(as.character(substitute(parameters))," is not a \"vector\" object.", call.=FALSE)
    } else {
        if(length(parameters) != 3) {
            stop("Wrong format for ",as.character(substitute(parameters)),", must be a vector of three elements:\nthe number of generations ; the sampling and the burnin.", call.=FALSE) 
        }
    }

    #priors
    if(is.null(priors)) {
        prior.default=TRUE
    } else {
        prior.default=FALSE
        if(class(priors) != 'list') {
            stop("Wrong format for ",as.character(substitute(priors)),", must be a list of three elements:\nsee ?MCMCglmm manual.", call.=FALSE) 
        }
    }

    #convergence
    if(class(convergence) != 'numeric') {
        stop("\"convergence\" must be numeric.", call.=FALSE) 
    } else {
        if(length(convergence) != 1) {
            stop("\"convergence\" must be numeric.", call.=FALSE) 
        }
    }

    #ESS
    if(class(ESS) != 'numeric') {
        stop("\"ESS\" must be numeric.", call.=FALSE) 
    } else {
        if(length(ESS) != 1) {
            stop("\"ESS\" must be numeric.", call.=FALSE) 
        }
    }

    #verbose
    if(class(verbose) != 'logical') {
        stop("\"verbose\" must be logical.", call.=FALSE) 
    }

    #output
    if(class(output) == 'logical') {
        if(output==FALSE){
            do.output=FALSE
            cat("No output option selected, this might highly decrease the performances of this function.")
        } else {
            do.output=TRUE
            output="mulTree.out"
            cat("Analysis output is set to \"mulTree.out\" by default.\nTo modify it, specify the output chain name using:\nmulTree(..., output=<OUTPUT_NAME>, ...)\n") 
        }
    }
    if(class(output) != 'logical') {
        if(class(output) != 'character') {
            stop(as.character(substitute(output)),", must be a chain of characters", call.=FALSE) 
        } else {
            if(length(output) != 1) {
                stop(as.character(substitute(output)),", must be a chain of characters", call.=FALSE) 
            } else {
                do.output=TRUE
            }
        }
    }

    #warn
    if(class(warn) != 'logical') {
        stop("\"warn\" must be logical.", call.=FALSE) 
    }


#FUNCTION


    FUN.MCMCglmm<-function(ntree, mulTree.data, formula, priors, parameters, warn, ...){
        require(MCMCglmm)
        #Model running using MCMCglmm function (MCMCglmm) on each tree [i] on two independent chains
        if(warn == FALSE) {
            options(warn=-1) #Disable warning for now
        }
        model<-MCMCglmm(formula, random=~animal, pedigree=mulTree.data$phy[[ntree]], prior=priors, data=mulTree.data$data, verbose=FALSE, nitt=parameters[1], thin=parameters[2], burnin=parameters[3], ...)
        if(warn == FALSE) {
            options(warn=0) #Re-enable warnings
        }
        return(model)
    }

    FUN.convergence.test<-function(chains){
        #Creating the mcmc.list
        list.mcmc<-list()
        for (nchains in 1:chains){
            list.mcmc[[nchains]]<-as.mcmc(get(paste("model_chain",nchains,sep=""))$Sol[1:(length(get(paste("model_chain",nchains,sep=""))$Sol[,1])),])
        }

        #Convergence check using Gelman and Rubins diagnoses set to return true or false based on level of scale reduction set (default = 1.1)
        convergence<-gelman.diag(mcmc.list(list.mcmc))
        return(convergence)
    }


#RUNNING THE MODELS

    #Creating the list of file names per tree
    file.names<-vector("list", length(mulTree.data$phy))
    for (ntree in (1:length(mulTree.data$phy))){
        file.names[[ntree]]<-paste(output, as.character("_tree"), as.character(ntree), sep="")
    }
    #Adding the chain name
    for (nchains in 1:chains) {
        file.names.chain<-paste(file.names, as.character("_chain"), as.character(nchains), as.character(".rda"), sep="")
        assign(paste("file.names.chain", nchains, sep=""), file.names.chain)
    }
    #Adding the convergence name
    file.names.conv<-paste(file.names, as.character("_conv"), as.character(".rda"), sep="")

    #Running the models n times for every trees
    for (ntree in 1:length(mulTree.data$phy)) {
        
        #Running the model for one tree
        for (nchains in 1:chains) {
            model_chain<-FUN.MCMCglmm(ntree, mulTree.data, formula, priors, parameters, ..., warn)
            assign(paste("model_chain", nchains, sep=""), model_chain)
        }

        #Saving models
        if(do.output == TRUE) {
            for (nchains in 1:chains) {
                model<-get(paste("model_chain",nchains,sep=""))
                name<-get(paste("file.names.chain",nchains,sep=""))[[ntree]]
                save(model, file=name)
            }
        }

        #Testing the convergence for one tree
        if(multiple.chains == TRUE) {
            converge.test<-FUN.convergence.test(chains)
        }

        #Saving convergence
        if(do.output == TRUE & multiple.chains == TRUE) {
            save(converge.test, file=file.names.conv[ntree])
        }

        #Verbose
        if(verbose == TRUE) {
            cat("\n",format(Sys.Date())," - ",format(Sys.time(), "%H:%M:%S"), ":", " MCMCglmm performed on tree ", as.character(ntree),"\n",sep="")
            if(multiple.chains == TRUE) {
                cat("Convergence diagnosis:\n")
                cat("Effective sample size is > ", ESS, ": ", all(effectiveSize(model$Sol[])>ESS), "\n", sep="")
                cat(effectiveSize(get(paste("model_chain",nchains,sep=""))$Sol[]), "\n", sep=" ")
                cat("All levels converged < ", convergence, ": ", all(converge.test$psrf[,1]<convergence), "\n", sep="")
                cat(converge.test$psrf[,1], "\n", sep=" ")
            }
            if(do.output == TRUE){
                if(multiple.chains == TRUE) {
                    cat("Models saved as ", file.names[[ntree]], "_chain*.rda\n", sep="")
                    cat("Convergence diagnosis saved as ", file.names.conv[ntree],"\n", sep="")
                } else {
                    cat("Model saved as ", file.names[[ntree]], "_chain1.rda\n", sep="")
                }
            }          
        }
    }


#OUTPUT

    #timer (end)
    end.time <- Sys.time()
    execution.time<- difftime(end.time,start.time, units="secs")

    #verbose
    if(verbose==TRUE) {
        cat("\n",format(Sys.Date())," - ",format(Sys.time(), "%H:%M:%S"), ":", " MCMCglmm successfully performed on ", length(mulTree.data$phy), " trees.\n",sep="")
        if (execution.time[[1]] < 60) {
            cat("Total execution time: ", execution.time[[1]], " secs.\n", sep="")
        } else {
            if (execution.time[[1]] > 60 & execution.time[[1]] < 3600) {
                cat("Total execution time: ", execution.time[[1]]/60, " mins.\n", sep="") 
            } else {
                if (execution.time[[1]] > 3600 & execution.time[[1]] < 86400) {
                   cat("Total execution time: ", execution.time[[1]]/3600, " hours.\n", sep="")
                } else {
                    if (execution.time[[1]] > 86400) {
                        cat("Total execution time: ", execution.time[[1]]/86400, " days.\n", sep="")
                    }
                }
            }
        }

        cat("Use read.mulTree() to read the data as 'mulTree' data.\nUse summary.mulTree() and plot.mulTree() for plotting or summarizing the 'mulTree' data.\n", sep="")
    }

#End
}

#example
mulTree.example=FALSE
if(mulTree.example == TRUE) {
    #DUMMY EXAMPLE
    data_table<-data.frame(taxa=LETTERS[1:5], var1=rnorm(5), var2=c(rep('a',2), rep('b',3)))
    #Creates a list of trees
    trees_list<-list() ; for (i in 1:5) {trees_list[[i]]<-rcoal(5, tip.label=LETTERS[1:5])} ; class(trees_list)<-'multiPhylo'
    #Creates the "mulTree" object
    mulTree_data<-as.mulTree(data_table, trees_list, species="taxa")
    #formula
    form=var1~var2
    #parameters
    param=c(100000, 1000, 25000)
    #priors
    prior<-list(R = list(V = 1/2, nu=0.002), G = list(G1=list(V = 1/2, nu=0.002)))

    #mulTree
    mulTree(mulTree_data, form, param, priors=prior, verbose=TRUE, warn=FALSE)

    #EMPIRICAL EXAMPLE
    mam_aves_tres<-read.tree("example/10trees_mammal-aves.tre")
    long_data<-read.csv("example/425sp_LongevityData.csv")
    longevity.data<-as.mulTree(long_data, mam_aves_tres, species="species.m")
    formu<-long.m~BMR + mass.m + volant.m + mass.m:volant.m
    param<-c(1000, 50, 250)
    prior<-list(R = list(V = 1/2, nu=0.002), G = list(G1=list(V = 1/2, nu=0.002)))
    outpu<-"longevity"
    #mulTree
    mulTree(longevity.data, formu, param, chains=2, prior, verbose=TRUE, output=outpu, warn=FALSE)

}
