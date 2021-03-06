unpipe <- function(expr, eval_ = FALSE) {
  pipe_sym <- c("%>%", "%>>%")
  
  cnv <- function(x) {
    lhs <- x[[2]]
    rhs <- x[[3]]
    
    if (any(pipe_sym %in% all.names(rhs))) rhs <- expand_pipe(rhs)
    if (any(pipe_sym %in% all.names(lhs))) lhs <- expand_pipe(lhs)
        
    # main
    if (any(all.names(rhs) == ".")) {
      replace_dots(rhs, lhs) }
    else if (is.symbol(rhs) || rhs[[1]] == "function" || rhs[[1]] == "(") {
      as.call(c(rhs, lhs)) }
    else if (is.call(rhs)) {
      as.call(c(rhs[[1]], lhs, as.list(rhs[-1]))) }
    else {
      stop("missing condition error") }
  }
  
  decomp <- function(x, exit_fn, pred_fn, cnv_fn) {
    if (exit_fn(x)) x
    else if (pred_fn(x)) cnv_fn(x)
    else if (is.pairlist(x)) as.pairlist(lapply(x, decomp, exit_fn, pred_fn, cnv_fn))
    else as.call(lapply(x, decomp, exit_fn, pred_fn, cnv_fn)) }
  
  replace_dots <- function(expr, expr_new) {
    # not expand `~` because a dot is sometimes used in a formula's argument
    decomp(expr, 
      function(x) (length(x) <= 1 && x != ".") || (is.call(x) && x[[1]] == "~"),
      function(x) is.symbol(x) && x == ".", # faster than identical(x, quote(.))
      function(x) expr_new ) }

  expand_pipe <- function(expr) {
    decomp(expr, 
      function(x) length(x) <= 1, # NULL, list(), numeric(0)
      function(x) length(x) == 3 && as.character(x[[1]]) %in% pipe_sym,
      function(x) cnv(x) ) }
  
  target <- if (is.symbol(tmp <- substitute(expr))) expr else tmp
  
  if (eval_) eval(expand_pipe(target), parent.frame())
  else expand_pipe(target)
  
}

###
## see  
## http://cran.r-project.org/web/packages/magrittr/vignettes/magrittr.html

## those are old magrittr's examples
## unzip this file and extract and see a vignette file.
## http://cran.r-project.org/src/contrib/Archive/magrittr/magrittr_1.0.0.tar.gz

## unpipe() does not support new features of magrittr such as creating a unary function.

# install.packages("magrittr")
library("magrittr")
exam1 <- quote(
  weekly <-
    airquality %>% 
    transform(Date = paste(1973, Month, Day, sep = "-") %>% as.Date) %>% 
    aggregate(. ~ Date %>% format("%W"), ., mean)
)

(exam1_ <- unpipe(exam1))
# weekly <- aggregate(. ~ format(Date, "%W"), transform(airquality, 
#     Date = as.Date(paste(1973, Month, Day, sep = "-"))), mean)

identical(unname(eval(exam1)), unname(eval(exam1_)))
# [1] TRUE

exam2 <- quote(
  windy.weeks <-
    airquality %>% 
    transform(Date = paste(1973, Month, Day, sep = "-") %>% as.Date) %>% 
    aggregate(. ~ Date %>% format("%W"), ., mean) %>%
    subset(Wind > 12, c(Ozone, Solar.R, Wind)) %>% 
    print
)
(exam2_ <- unpipe(exam2))
# windy.weeks <- print(subset(aggregate(. ~ format(Date, "%W"), 
#     transform(airquality, Date = as.Date(paste(1973, Month, Day, 
#         sep = "-"))), mean), Wind > 12, c(Ozone, Solar.R, Wind)))

identical(eval(exam2), eval(exam2_))
#      Ozone  Solar.R     Wind
# 2 15.40000 192.6000 12.28000
# 3 18.14286 203.4286 12.45714
# 7 27.00000 207.6667 14.53333
#      Ozone  Solar.R     Wind
# 2 15.40000 192.6000 12.28000
# 3 18.14286 203.4286 12.45714
# 7 27.00000 207.6667 14.53333
# [1] TRUE

exam3 <- quote(
  windy.weeks %>%
    (function(x) rbind(x %>% head(1), x %>% tail(1)))
)
(exam3_ <- unpipe(exam3))
# (function(x) rbind(head(x, 1), tail(x, 1)))(windy.weeks)
identical(eval(exam3), eval(exam3_))
# [1] TRUE

exam4 <- quote(1:10 %>% (substitute(f(), list(f = sum))))
(exam4_ <- unpipe(exam4))
# (substitute(f(), list(f = sum)))(1:10)
### invalid semantics
identical(eval(exam4), eval(exam4_))
# Error in eval(expr, envir, enclos) : attempt to apply non-function

exam5 <- quote(1:10 %>% (substitute(f, list(f = sum))))
exam5_ <- unpipe(exam5)
identical(eval(exam5), eval(exam5_))
# [1] TRUE

exam6 <- quote(
  rnorm(1000)    %>%
  multiply_by(5) %>%
  add(5)         %>%
  (function(x) {
    cat("Mean:",     x %>% mean, 
        "Variance:", x %>% var,  "\n")
  })
)
(exam6_ <- unpipe(exam6))
# (function(x) {
#     cat("Mean:", mean(x), "Variance:", var(x), "\n")
# })(add(multiply_by(rnorm(1000), 5), 5))

{ 
  set.seed(6); eval(exam6);
  set.seed(6); eval(exam6_)
}

# Mean: 4.873632 Variance: 25.47606 
# Mean: 4.873632 Variance: 25.47606 


### Evaluation of unpiped syntax is faster than using %>%, but some cases
### are different.

library("microbenchmark")
microbenchmark(eval(exam1), eval(exam1_))
# Unit: milliseconds
#          expr      min       lq   median       uq      max neval
#   eval(exam1) 29.85074 30.59207 31.14484 32.10594 39.11404   100
#  eval(exam1_) 40.96314 42.22023 42.65286 43.57629 47.32218   100

microbenchmark(eval(exam2), eval(exam2_))
#          expr      min       lq   median       uq      max neval
#   eval(exam2) 33.67598 34.96049 35.67641 36.92014 42.39765   100
#  eval(exam2_) 44.45002 45.83840 46.53850 47.86536 90.73086   100

# > library(profr)
# > profr(eval(exam2))
# > profr(eval(exam2_))

microbenchmark(eval(exam3), eval(exam3_))
# Unit: milliseconds
#          expr      min       lq   median       uq      max neval
#   eval(exam3) 2.670220 2.799720 2.943707 3.160801 4.904468   100
#  eval(exam3_) 1.278497 1.333773 1.401978 1.551982 3.118229   100

microbenchmark(eval(exam4), eval(exam4_))
# Error in eval(expr, envir, enclos) : attempt to apply non-function

microbenchmark(eval(exam5), eval(exam5_))
# Unit: microseconds
#          expr     min      lq   median       uq     max neval
#   eval(exam5) 374.010 381.811 386.0460 399.8650 694.080   100
#  eval(exam5_)  12.928  14.266  15.1575  20.2835  84.253   100

microbenchmark(eval(exam6), eval(exam6_))
# Unit: microseconds
#          expr      min        lq   median        uq      max neval
#   eval(exam6) 3065.182 3155.0060 3243.939 3467.0520 5353.368   100
#  eval(exam6_)  615.177  632.3395  645.490  660.4235  995.873   100
# There were 50 or more warnings (use warnings() to see the first 50)
