### functional operators

### adopt `f.` instead of `f` because `f` often causes conflicts in many sample codes.
f. <- function(..., env = parent.frame()){
  # see https://gist.github.com/TobCap/6366396 for how to handle unevaluated `...` 
  d <- as.pairlist(as.vector(substitute((...)), "list")[-1])
  # need to be pairlist to return NULL when nothing is passed to `...`.
  
  n <- length(d)
  eval(call("function", as.pairlist(tools:::as.alist.call(d[-n])), d[[n]]), env)
}
# f. <- function(..., env = parent.frame()){
#   d <- lapply(substitute(list(...)), identity)[-1]
#   as.function(c(tools:::as.alist.call(d[-length(d)]), d[length(d)]), envir = env) 
# }
# The above commented code which I made first time is bit slower than the current code.
# See https://gist.github.com/TobCap/6255804 for comparison of cost of creating funciton.
# See also https://github.com/hadley/pryr/blob/master/benchmark/make-function.r

# arrow operator 
`%=>%` <- function(lhs, rhs, env = parent.frame()){
  l <- substitute(lhs)
  if (length(l) > 1 || class(l) == "{") l <- as.pairlist(as.vector(l, "list")[-1]) # avoid list()
  eval(call("function", as.pairlist(tools:::as.alist.call(l)), substitute(rhs)), env)
}

# {} %=>% {x + 2}
# x %=>% {x + 1}
# c(x, y) %=>% {x + y}
# c(x=1, y) %=>% {x + y}
# {x; y} %=>% {x + y} 
# {x=1; y} %=>% {x + y} # not run

# f.(x, x * 2)
# f.(x, y, x + y)
# f.(x, x * 2)(3)
# f.(x, y, x + y)(1, 2)
# f.(x, f.(y, x + y))(1)(2)

### saves to type anonymous function
# > Reduce(function(x, y) x + y, 1:10)
# [1] 55
# > Reduce(f.(x, y, x + y), 1:10)
# [1] 55

# > f.(y, f.(z, y+z))(1)(2)
# [1] 3
# > f.(y=1, f.(z=2, y+z))()()
# [1] 3

curry <- function (fun, env = parent.frame()) {
  has.quoted <- FALSE
  recursiveCall <- function(len, arg) {
    if (len == 0) return(do.call(fun, arg, quote = has.quoted, envir = env))
    function(x) {
      if(is.language(x)) has.quoted <<- TRUE
      recursiveCall(len - 1, append(arg, list(x)))}}
  recursiveCall(length(formals(args(fun))), list())
}

# particial application
# an undercore symbol `_` is requited to bind variales
 pa <- function(expr, e = parent.frame()){
   all.vars <- all.names(substitute(expr), functions = FALSE)
   underscores <- all.vars[grep("^\\_$|^\\_[0-9]+", all.vars)]
   if(length(underscores) == 0) stop("binding variable must be start underscore")
   created.formals <- tools:::as.alist.call(underscores[order(underscores)])

   make.body <- function(args_){
     if(length(args_) == 0) return(substitute(expr, parent.env(environment())))
     call("function", as.pairlist(args_[1]), make.body(args_[-1]))
   }

   eval(make.body(created.formals), e)
 }
# f1 <- pa(`_` * 2); f1(10)
# f2 <- pa(D(`_`, "x")); f2(quote(x^4))
# f3 <- pa(D(quote(x^5+2*y^4), `_`)); f3("x"); f3("y")
# 
# g <- function(x, y, z, w) 1000*x+100*y+10*z+1*w
# f3 <- pa(g(1, `_1`, 7, `_2`)); f3(3)(9)
# f4 <- pa(g(1, `_2`, 7, `_1`)); f4(3)(9)

# only closure is acceptable
cr <- function(f, e = parent.frame()){
   stopifnot(is.function(f) && typeof(f) == "closure")
   make.body <- function(args_){
     if(length(args_) == 0) return(body(f))
     call("function", as.pairlist(args_[1]), make.body(args_[-1]))
   }
   eval(make.body(formals(args(f))), envir = environment(f), enclos = e)
 }

# h1 <- cr(rnorm); h1(10)(100)(1)
# h2 <- cr(rnorm)(10)(100); h2(1)
# h3 <- cr(D); h3(quote(x^5))("x")
# h4 <- cr(D)(quote(x^5)); h4("x")
# plus2 <- curry(`+`)(2)
# plus2(10) # 12

# curry(D)(quote(x^5))("x")
# previous version of `curry` does not run on above code.

### flip is defined below
# divBy10 <- curry(flip(`/`))(10)
# divBy10(24) # = 2.4

# > curry(function(x, y, z) x + y + z)(1)(2)(3)
# [1] 6
### `f.` is already defined above and save your typing.
# > curry(f.(x, y, z, x + y + z))(1)(2)(3)
# [1] 6
# > f.(x, y, z, x + y + z) %|>% curry %<|% 1 %<|% 2 %<|% 3
# [1] 6

# unsurpported: if one of fun's arguments is dot-dot-dot, it does not work
# > call("rnorm", 5, 100)
# rnorm(5, 100)
# > curry(call)("rnorm")(5)(100)
# エラー:  関数でないものを適用しようとしました 

### curried function creator
λ <- l. <- function(...) curry(f.(..., env = parent.frame()), env = parent.frame())
### Address of λ (lambda) in Unicode is U+03BB or \u03BB
# λ(g, x, g(g(x)))(λ(y, y+1))(5)
# f.(g, f.(x, g(g(x))))(f.(y, y+1))(5)
# l.(g, l.(x, g(g(x))))(l.(y, y+1))(5)
# l.(g, x, g(g(x)))(l.(y, y+1))(5)

### http://www.angelfire.com/tx4/cus/combinator/birds.html
# S <- f.(x, f.(y, f.(z, (x(z))(y(z)) )))
# K <- f.(x, f.(y, x))
# I <- S(K)(K) # f.(x, x) 

# see https://gist.github.com/TobCap/6255395
uncurry <- function(fun){ 
  function(...){
    rec <- function(f, dots){
      if(length(dots) == 0) f
      else rec(f(dots[[1]]), dots[-1])
    }
    rec(fun, list(...))
  }
}
# > g <- function(x) function(y) function(z) x + y + z
# > g(1)(2)(3)
# [1] 6
# > uncurry(g)(1, 2, 3)
# [1] 6

###
flip <- function(.fun, l = 1, r = 2, env = parent.frame()){
  args.orig <- formals(args(match.fun(.fun)))
  stopifnot(1 < r && l < length(args.orig) && l < r)
  .fun.name <- as.character(substitute(.fun))
  out.fun <- function() {
    args. <- as.pairlist(lapply(match.call(), force)[-1])
    args.[c(r, l)] <- args.[c(l, r)]
    do.call(.fun.name, args., envir = env)
  }
  formals(out.fun) <- args.orig
  out.fun
}

### examples
# > flip(`-`)(2, 5)
# [1] 3

# > flip(sapply)(sqrt, 1:4)
# [1] 1.000000 1.414214 1.732051 2.000000

# > flip(sapply)(round, 1:10/100, 2)
#  [1] 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10

# > Dx <- curry(flip(D))("x")
# > nest.fun(Dx, 5)(quote(x^10)) # nest.fun is defined below.
# 10 * (9 * (8 * (7 * (6 * x^5))))

###
# fun compares vecter elements next to each other
.compare <- function(fun, vals){
  out.fun <- function(vals){
    if(length(vals) == 1) TRUE
    else if(is.na(vals[[1]])) NA
    else if(!fun(vals[[1]], vals[[2]])) FALSE
    else out.fun(vals[-1])
  }
  out.fun(vals)
}

.compare.vec <- function(fun, vals, type = c("all", "any")){
  all.or.any <- match.fun(match.arg(type))
  all.or.any(match.fun(fun)(vals[-length(vals)], vals[-1]))
}

`<.`  <- function(.) .compare(`<` , .) # .compare.vec("<" , .)
`<=.` <- function(.) .compare(`<=`, .) # .compare.vec("<=", .)
`>.`  <- function(.) .compare(`>` , .) # .compare.vec("<" , .)
`>=.` <- function(.) .compare(`>=`, .) # .compare.vec("<=", .)
`==.` <- function(.) .compare(`==`, .) # .compare.vec("==", .)
# `!=` is not a transitive relation, so '!=.' cannnot be defined as the same way. 

# `<.`(1:100)
# `<=.`(c(1:100,99))

.compare.element <- function(vals, default.val){
  if(length(vals) == 0) default.val
  else if(is.na(vals[[1]])) NA
  else if(!vals[[1]] == default.val) !default.val
  else .compare.element(vals[-1], default.val)
}
.all <- function(x) .compare.element(x, TRUE)
.any <- function(x) .compare.element(x, FALSE)

###
# avoiding conflict with utils::zip
# 結局 mapply
zip. <- function(..., FUN = list){
  dot.args <- list(...)
  args.seq <- seq_len(min(vapply(dot.args, length, 0)))
  args.new <- lapply(dot.args, function(x) x[args.seq])
  do.call(mapply, c(FUN = FUN, args.new, SIMPLIFY = FALSE, USE.NAMES = FALSE))
}

zipWith. <- function(fun, ..., do.unlist = FALSE) {
  if (do.unlist) unlist(zip.(..., FUN = match.fun(fun)))
  else zip.(..., FUN = match.fun(fun))
}

# zip.(list(1,2,3), list(4,5,6))
# zip.(1:3, 4:6)

# zip.(list(1,2,3), list(4,5,6), list(7,8,9))
# zip.(1:3, 4:6, 7:9)
# zip..(1:3, letters[1:3])

# zipWith(f.(x,y, 2*x+y), 1:4, 5:8)
#
# > func <- function(x) x %|% zip.(.., 0:(length(x)-1)) %|% Map(prod, ..) %|% Reduce(`+`, ..)
# > func(seq(10, 50, by=10))
# [1] 400
#
### http://mew.org/~kazu/material/2011-haskell.pdf
### Ruby
# def func (ar)
# ar.zip((0..ar.length).to_a) \
# .map{|(x,i)|x*i} \
# .reduce(:+);
# end
# func([10,20,30,40,50]);
# → 400

### http://neue.cc/2011/02/14_302.html
"%|>%" <- function(x, f) f(x)
"%<|%" <- function(f, x) f(x)

### functional composition
"%>>%" <- function(f, g) function(x) g(f(x))
"%<<%" <- function(f, g) function(x) f(g(x))
compose. <- function(f, g) function(x) f(g(x))
# f1 <- f.(x, {cat("f1(x = ", x, ") -> ", sep = ""); x + 1})
# f2 <- f.(x, {cat("f2(x = ", x, ") -> ", sep = ""); x * 2})
# f3 <- f.(x, {cat("f3(x = ", x, ") -> ", sep = ""); x / 3})
# f4 <- f1 %>>% f2 %>>% f3
# f5 <- f1 %<<% f2 %<<% f3

# > f4(1)
# f1(x = 1) -> f2(x = 2) -> f3(x = 4) -> [1] 1.333333
# > f5(1)
# f3(x = 1) -> f2(x = 0.3333333) -> f1(x = 0.6666667) -> [1] 1.666667

### Pipeline like operator
### Left value can be passed by ".." just like scala's underscore "_".
### I use ".."; "." is already used in "package:plyr".
### It is not fast but easy to read and understand because of using fewer parentheses.
"%|%" <- function(lhs, rhs){
  ans <- eval(substitute(rhs), envir = list(.. = lhs))  
  if (is.function(ans))
    ans(lhs)  
  else if (all(typeof(ans)=="logical", length(lhs)==length(ans)))
    lhs[ans]
  else
    ans
}

# > 1:5 %|% f.(x, x-1) %|% f.(x, x^2)
# [1]  0  1  4  9 16
# > 1:5 %|% (..-1) %|% (..^2)
# [1]  0  1  4  9 16
# > 1:5 %|% {..-1} %|% {..^2}
# [1]  0  1  4  9 16

### the same
# > Filter(function(x) x%%2==0, 1:5)
# [1] 2 4
# > 1:5 %|% (..%%2==0)
# [1] 2 4

# here, with %|% operator, right assignment is useful to define a variable
# > 1:10 %|% (..%%2==0) %|% ..^2 -> x
# > x
# [1]   4  16  36  64 100

### plot brownian motion in one liner
# > f.({mu<-0;m<-252;sigma<-0.2/sqrt(m) ;rnorm(m, mu-sigma^2/2, sigma) %|% cumsum %|% c(0, ..)}) %|% replicate(n=1000, ..()) %|% matplot(.., type = "l", ann = FALSE)

### set break lines after typing `%|%`
# f.({mu<-0;m<-252;sigma<-0.2/sqrt(m) ;rnorm(m, mu-sigma^2/2, sigma) %|% 
#   cumsum %|% 
#   c(0, ..)}) %|% 
# replicate(n=1000, ..()) %|% 
# matplot(.., type = "l", ann = FALSE);

`<--` <- function(...){
  Reduce("%<|%", list(...), right = TRUE)
}
`-->` <- function(...){
  Reduce("%|>%", list(...), right = FALSE)
}
 
# > `-->`(1:5, f.(x, x-1), f.(x, x*10))
# [1]  0 10 20 30 40
 
`<<--` <- function(...){
    Funcall <- function(f, ...) f(...)
    function(x) Reduce(Funcall, list(...), x, right = TRUE)
}
`-->>` <- function(...){
    Funcall <- function(f, ...) f(...)
    function(x) Reduce(Funcall, rev(list(...)), x, right = TRUE)
}
 
# > `-->>`(f.(x, x-1), f.(x, x*10))(1:5)
# [1]  0 10 20 30 40

### invokes interceptor; the idea comes from underscore javascript.
### it easy to debug.
tap <- function(x, fun) {
  if(missing(fun)) print(x) else print(fun(x))
  x
}
# > 1:10 %|% (..%%2==0) %|% tap %|% ..^2
# [1]  2  4  6  8 10
# [1]   4  16  36  64 100

# > cos(log(sin(pi/2)))
#
# > cos %<<% log %<<% sin %<|% (pi/2)
# > (pi/2) %|>% {cos %<<% log %<<% sin}
# > sin %>>% log %>>% cos %<|% (pi/2)
# > (pi/2) %|>% {sin %>>% log %>>% cos}
#
### code flows from left to right; no need to use round bracket!
### http://yuroyoro.hatenablog.com/category/%E9%96%A2%E6%95%B0%E5%9E%8B%E8%A8%80%E8%AA%9E
# > (pi/2) %|% sin %|% log %|% cos
# > (pi/2) %|>% sin %|>% log %|>% cos

### fixed-point combinator
### I tried to check four types of fixed-point combinator function and blow is the simplest and fastest
fix. <- function(g) {f <- g(f)}

### http://en.wikipedia.org/wiki/Fixed-point_combinator

# fix0 <- function(g) g(fix0(g))
# fix1 <- function(g) f <- g(f)
# fix2 <- function(f) (function(x) f(x(x)) )(function(x) f(x(x)))
# fix3 <- function(f) (function(x) f(function(y) x(x)(y)))(function(x) f(function(y) x(x)(y)))
# fix4 <- function(f) (function(x) function(y) f(x(x))(y))(function(x) function(y) f(x(x))(y))

### Y g =  g (Y g)
### g = Y(f), f(g) = g
### Y = λf・(λx・f (x x)) (λx・f (x x))
### Z = λf.(λx.f (λy. x x y)) (λx.f (λy. x x y))

# mult_maker <- function(f) function(x) if (x == 1) 1 else x * f(x-1)
# > microbenchmark(fix0(mult_maker)(100),fix1(mult_maker)(100),fix2(mult_maker)(100), fix3(mult_maker)(100), fix4(mult_maker)(100))
# Unit: microseconds
# expr     min       lq   median       uq      max
# 1 fix0(mult_maker)(100) 200.585 207.0100 211.7595 219.1625  289.423
# 2 fix1(mult_maker)(100) 119.010 124.0385 126.9725 131.8615  191.086
# 3 fix2(mult_maker)(100) 204.775 212.8770 217.6260 224.0510  302.553
# 4 fix3(mult_maker)(100) 250.312 260.7875 267.2135 277.9690 1124.725
# 5 fix4(mult_maker)(100) 250.591 263.3020 267.9115 279.7845 1121.372

### refers to javascript.
### http://d.hatena.ne.jp/r-west/20090422/1240400570
gen.memoizer <- function(stored.env, reset = FALSE){
  if(missing(stored.env))
    stored.env <- tryCatch(as.environment("functionalProgramming.r"),
      error = function(e) attach(NULL, name="functionalProgramming.r"))
  
  stopifnot(is.environment(stored.env))
  
  .memo <- 
    if(exists(".memo", envir = stored.env)) get(".memo", envir = stored.env)
    else assign(".memo", new.env(parent = emptyenv()), envir = stored.env)
  
  if(reset) return(invisible(rm(list = ls(.memo, all = T), envir = .memo)))
  
  function(f) {
    n <- sys.parent() - 1 # adhoc, need to investigate and modify
    fun.names <- 
      if (n > 0) paste0(deparse(sys.function(n)), collapse = "")
      else paste0(deparse(f), collapse="")
    
    function(...){
      key <- paste0(c(...), collapse=",")
      if (!exists(fun.names, envir = .memo)) 
        assign(fun.names, new.env(parent = emptyenv()), envir = .memo)
      if(is.null(.memo[[fun.names]][[key]]))
        .memo[[fun.names]][[key]] <- f(...)
      .memo[[fun.names]][[key]]
    }
  }
}

# previous simple version
# gen.memoizer <- function () {
  # function(f) {
    # function(...){
      # key <- paste(list(...), collapse=",")
      # if (is.null(.memo[[key]])) .memo[[key]] <- f(...)
      # .memo[[key]]
    # }
  # }
# }
gen.tracer <- function () {
  num <- 0
  function(f) {
    function(...){
      key <- paste(list(...), collapse=",")
      num <<- num + 1 # keyより下でないといけない 副作用の弊害
      cat(num, if(num <= 3) switch(num, "st", "nd", "rd") else "th", " call with argument: ", key, "\n", sep = "")
      f(...)
    }
  }
}
###

fib_maker <- function(f) function(x) if (x <= 1) x else f(x - 1) + f(x - 2)
# > fix.(fib_maker)(5)
# [1] 5
# > fix.(gen.tracer() %>>% fib_maker)(5)
# 1st call with argument: 4
# 2nd call with argument: 3
# 3rd call with argument: 2
# 4th call with argument: 1
# 5th call with argument: 0
# 6th call with argument: 1
# 7th call with argument: 2
# 8th call with argument: 1
# 9th call with argument: 0
# 10th call with argument: 3
# 11th call with argument: 2
# 12th call with argument: 1
# 13th call with argument: 0
# 14th call with argument: 1
# [1] 5
## see the chart in http://mitpress.mit.edu/sicp/full-text/sicp/book/node16.html
## and compare it with above outputs.

### gen.memoizer() needs to be just leftside of memoizing function
# > fix.(gen.tracer() %>>% gen.memoizer() %>>% fib_maker)(5)
# 1st call with argument: 4
# 2nd call with argument: 3
# 3rd call with argument: 2
# 4th call with argument: 1
# 5th call with argument: 0
# [1] 5

### all results are the same
# fix.(gen.tracer() %>>% gen.memoizer() %>>% fib_maker)(5)
# (gen.tracer() %>>% gen.memoizer() %>>% fib_maker %|>% fix.)(5)
# {gen.tracer() %>>% gen.memoizer() %>>% fib_maker %|>% fix.}(5)
# 5 %|>% {gen.tracer() %>>% gen.memoizer() %>>% fib_maker %|>% fix.}
# gen.tracer() %>>% gen.memoizer() %>>% fib_maker %|>% fix. %<|% 5

# gen.memoizer() set results into `.memo` in a given environment.
# gen.memoizer(reset = TRUE) resets objects in `.memo`.

# > gen.memoizer(reset = TRUE) # reset
# > ls(.memo, all=T)
# character(0)

# > fix.(gen.tracer() %>>% gen.memoizer() %>>% fib_maker)(5)
# 1st call with argument: 4
# 2nd call with argument: 3
# 3rd call with argument: 2
# 4th call with argument: 1
# 5th call with argument: 0
# [1] 5

### the result is memoised.
# > fix.(gen.tracer() %>>% gen.memoizer() %>>% fib_maker)(5)
# [1] 5

### only new arguments are passed to calculation
# > fix.(gen.tracer() %>>% gen.memoizer() %>>% fib_maker)(7)
# 1st call with argument: 6
# 2nd call with argument: 5
# [1] 13

# > ls(.memo)
# [1] "function (x) if (x <= 1) x else f(x - 1) + f(x - 2)"

# > eapply(.memo, ls)
# $`function (x) if (x <= 1) x else f(x - 1) + f(x - 2)`
# [1] "0" "1" "2" "3" "4" "5" "6"

# > eapply(.memo, sapply, identity)
# $`function (x) if (x <= 1) x else f(x - 1) + f(x - 2)`
# 0 1 2 3 4 5 6 
# 0 1 1 2 3 5 8 

# fib <- gen.memoizer()(function(x) if(x <= 1) x else fib(x - 1) + fib(x - 2))

# > fib(500)
# [1] 1.394232e+104

# install.packages("gmp"); library("gmp")
# > fib2 <- gen.memoizer()(function(x) if(x<=1) as.bigz(x) else fib2(x-1) + fib2(x-2))
# > fib2(500)
# Big Integer ('bigz') :
# [1] # 139423224561697880139724382870407283950070256587697307264108962948325571622863290691557658876222521294125

### http://d.hatena.ne.jp/einblicker/20110108/1294448477
### http://d.hatena.ne.jp/einblicker/20110113/1294920315

### language object operater
symbol.tracker <- function(., n = 1, strict = TRUE) {
  # see https://gist.github.com/TobCap/6473028
  if(strict) stopifnot(n <= sys.parent())
  stack.adjust <- 2
  tmp1 <- quote(substitute(.))
  for(i in seq_len(n)){
    tmp1 <- call("substitute", tmp1)
  }
  tmp2 <- tmp1
  for(i in seq_len(n)){
    tmp2 <- call("eval", tmp2, substitute(parent.frame(k), list(k = i + stack.adjust)))
  }
  eval(tmp2)
}

### convert call to list and vice versa
call.list.cnv <- function(f.arg){
  arg.is.lang <- is.call(f.arg)
  cnv <- function(x){
    if (length(x) == 1) x
    else if (is.pairlist(x)) as.pairlist(lapply(x, cnv))
    else if (arg.is.lang) lapply(x, cnv) else as.call(lapply(x, cnv))
  }
  cnv(f.arg)
}
as.list.recursive <- function(x) {stopifnot(is.call(x)); call.list.cnv(x)}
as.call.recursive <- function(x) {stopifnot(is.list(x)); call.list.cnv(x)}

# language replacement
# see https://gist.github.com/TobCap/6348892 
replace.symbol <- function(expr, before, after){
  stopifnot(is.language(expr))
  before.after.list <- list(after)
  names(before.after.list)[[1]] <- deparse(before)
  eval(substitute(substitute(e, before.after.list), list(e = expr)))
}

replace.call <- function(expr, before, after){
  stopifnot(is.language(expr))
  conv <- function(x) {
    if(is.pairlist(x) && !is.null(x)) {
      if(is.symbol(before)){ # for formal parameter
        ind <- match(as.character(before), names(x))
        names(x)[ind] <- as.character(after)
      }
      as.pairlist(lapply(x, conv))
    }
    else if(identical(x, before)) after
    else if(length(x) == 1 || is.null(x)) x
    else as.call(lapply(x, conv))
  }
  conv(expr)
}

replace.multi <- function(expr, befores, after, replace.fun = replace.symbol){
  out.lang <- expr
  for(i in seq_along(befores)){
    out.lang <- replace.fun(out.lang, befores[[i]], after)
  }
  out.lang
}

replace.lang <- function (expr, before, after, can.accept.undefined.var = FALSE){
  stopifnot(is.language(expr))
  if(can.accept.undefined.var) {
    stopifnot(exists("accept.undefined.var"))
    before <- accept.undefined.var(before)
    after <- accept.undefined.var(after)
  }
  # before is passed as list even though it is a single symbole
  before <- 
    if (is.function(before)) before 
    else if (is.list(before) || is.expression(before)) as.list(before) 
    else list(before) # Being passed to function `matched` requires to be list object.
  after <- if (is.expression(after)) as.list(after) else after
  
  matched <- 
    if(is.function(before)) before 
    else function(m) any(vapply(before, identical, logical(1), m))
    
  conv <- function(x) {
    if(is.pairlist(x) && !is.null(x)) {
      if(is.function(before)){
        ind <- match(TRUE, sapply(lapply(names(x), as.name), before))
        names(x)[ind] <- as.character(after)
      } else if(is.symbol(before[[1]])){       
        ind <- match(as.character(before), names(x))
        names(x)[ind] <- as.character(after)
      }
      as.pairlist(lapply(x, conv))
    }
    else if(matched(x)) after
    else if(length(x) == 1 || is.null(x)) x
    else as.call(lapply(x, conv))
  }
  conv(expr)
}
 
accept.undefined.var <- function(.x) {
  # undefined handling
  is.defined <- tryCatch(nchar(.x) && TRUE, error = function(e) FALSE)
  
  expr <- eval.parent(substitute(substitute(.x)))
  lang.fun.names <- c("quote", "expression", "as.name", "as.symbol", "call")
  is.list.vector <- !is.symbol(expr) && (expr[[1]] == quote(c) || expr[[1]] == quote(list))
  w <- function(x) warning(
    paste0("the '", x,"' is an existing language object,so not interpreted as undefined variable"))
 
  force.lang <- function(y){
    var.name.first <- as.character(y)[[1]]
    if(var.name.first %in% lang.fun.names[1:2]) y[[2]] # quote or expression
    else if(var.name.first %in% lang.fun.names[3:5]) eval(y) # as.symbol, as.name or call
    else if(is.defined && is.character(y)) parse(text = y)[[1]] # character 
    else if(is.defined && is.language(eval(y))) {w(var.name.first); eval(y)} # assigned language object
    else y # undefined, not language object, or not character object
  }
  
  if(is.list.vector) lapply(as.list(expr)[-1], force.lang)
  else force.lang(expr)
}

# replace.symbol(quote(x+y*z), quote(y), quote(www))
# replace.lang(quote(x + y ^ z), y, www, TRUE)

# > replace.symbol(quote(1+2+x^3), quote(x), quote(y))
# 1 + 2 + y^3
# > replace.symbol(quote(1+2+x^3), quote(2), quote(99)) 
# 1 + 2 + x^3 # cannot replace value
# > replace.call(quote(1+2+x^3), quote(2), quote(99))
# 1 + 99 + x^3 # ok

# > replace.symbol(quote(1+2+x^3) , quote(`+`), quote(`-`))
# 1 - 2 - x^3
# > eval(replace.symbol(quote(1+2+x^3) , quote(`+`), quote(`-`)), list(x = 2))
# [1] -9

# arguments need to be quoted
nest.formula <- function(expr, variable, num){
  if (num == 1) return(expr)
  else replace.call(nest.formula(expr, variable, num - 1), variable, expr)
}
# > nest.formula(quote((1+x)^2), quote(x), 3)
# (1 + (1 + (1 + x)^2)^2)^2
# > nest.formula(quote((1+x)^2), quote(1+x), 3)
# (((1 + x)^2)^2)^2
# > eval(nest.formula(quote(1+1/x), quote(x), 40), list(x = 1)) == (1+sqrt(5))/2
# [1] TRUE

### tail recursive
nest.fun <- function(f, n, acc.fun = identity){
  # compose. is already defined above.
  if (n == 0) return(acc.fun)
  else if (n %% 2 == 0) nest.fun(compose.(f, f), n / 2, acc.fun)
  else nest.fun(f, n - 1, compose.(f, acc.fun))
}
nest.fun2 <- function(f, n){
  if (n == 0) identity
  else compose.(f, nest.fun2(f, n - 1))
}
# > benchmark(tail.rec = nest.fun(function(x) {x}, 100)(0), simple = nest.fun2(function(x) {x}, 100)(0), replications=1e4)[,1:4]
#       test replications elapsed relative
# 2   simple        10000     3.2 2.666667
# 1 tail.rec        10000     1.2 1.000000
#
# > benchmark(tail.rec = nest.fun(function(x) {x}, 10)(0), simple = nest.fun2(function(x) {x}, 10)(0), replications=1e5)[,1:4]
#       test replications elapsed relative
# 2   simple       100000    3.30 1.240602
# 1 tail.rec       100000    2.66 1.000000
#
# > benchmark(tail.rec = nest.fun(function(x) {x}, 1)(0), simple = nest.fun2(function(x) {x}, 1)(0), replications=1e6)[,1:4]
#       test replications elapsed relative
# 2   simple      1000000    5.52 1.000000
# 1 tail.rec      1000000    8.31 1.505435



# > nest.fun(f.(x, 1 + 1/x), 100)(1) == (1+sqrt(5))/2
# [1] TRUE

### checking arguments using gen.tracer() function.
# > nest.fun(gen.tracer()(f.(x, 1 + 1/x)), 3)(1)
# 1st call with argument: 1
# 2nd call with argument: 2
# 3rd call with argument: 1.5
# [1] 1.666667

### http://en.wikipedia.org/wiki/Church_encoding
### http://taiju.hatenablog.com/entry/20120529/1338299884
# zero <- l.(f, x, x)
# one  <- l.(f, x, f(x))
# two  <- l.(f, x, f(f(x)))
# num  <- l.(n, f, x, nest.fun(f, n)(x))
#
# plus <- l.(m, n, f, x, m(f)(n(f)(x)))
# succ <- l.(n, f, x, f(n(f)(x)))
# mult <- l.(m, n, f, m(n(f)))
# toInt <- f.(n, n(f.(n, n + 1))(0))
# 
# toInt(plus(zero)(one))
# toInt(plus(one)(two))
# toInt(succ(one))
# toInt(num(99))
# toInt(plus(num(7))(num(8)))
# toInt(mult(num(3))(num(5)))
# num(3) %|>% mult %<|% num(5) %|% toInt

# tail call optimization
# see https://gist.github.com/TobCap/6482462 
tco <- function(f){
  # f is copied object; the original f is not changed.
  f.orig <- substitute(f) 
  body(f) <- replace.multi(body(f), c(quote(Recall), f.orig), quote(list)) 
  arg.names <- names(formals(f))

  out.fun <- function(){
    environment(f) <- e <- list2env(mget(arg.names), parent = environment(f))
    while(TRUE){
      ans <- f() # evaluate
      if (length(ans) == 1 && !is.list(ans)) break
      e <- list2env(stats:::setNames(ans, arg.names), envir = e) #update values
    }
    return(ans)
  }
  formals(out.fun) <- formals(f)
  formals(f) <- NULL # makes "f" find variables in "e".
  out.fun
}

sum.rec <- function(n, acc = 0){
  if(n == 0) acc
  else sum.rec(n - 1, acc + n)
}
# > sum.rec(10)
# [1] 55
# > sum.rec(1e5)
# エラー：  protect()：プロテクションスタック
# > tco(sum.rec)(1e5)
# [1] 5000050000

# pow.rec <- function(x, n, acc = 1){
#   if(n == 0) acc
#   else pow.rec(x, n - 1, x * acc)
# }
# > pow.rec(1+1e-5, 1e5)
#  エラー:  評価があまりに深く入れ子になっています。無限の再帰か options(expressions=)？ 
# > tco(pow.rec)(1+1e-5, 1e5)
# [1] 2.718268

lang2char <- function(expr, type = c("rexp", "sexp")){
  type <- match.arg(type)
  stopifnot(is.call(expr))
  
  r <- list(fst = function(x) as.character(list(x[[1]])), coll = ", ", print.out = function(first, rest) paste0(first, "(", rest, ")"))
  s <- list(fst = function(x) as.character(x[[1]]), coll = " ", print.out = function(first, rest) paste0("(", first, " ", rest, ")")) 
  . <- if(type == "rexp") r else s
  .$rst <- function(k) paste0(lapply(k, function(x) {if(length(x) == 1) as.character(x) else as.char(x)}) , collapse = .$coll)
  
  as.char <- function(k) .$print.out(first = .$fst(k), rest = .$rst(k[-1]))
  noquote(as.char(expr))
}

# > lang2char(quote(x+sin(y*z)))
# [1] `+`(x, sin(`*`(y, z)))
# > eval(parse(text="`+`(x, sin(`*`(y, z)))"), list(x=1, y=2, z=3))
# [1] 0.7205845

### S-expression
# > lang2char(quote(x+sin(y*z)), "s")
# [1] (+ x (sin (* y z)))

# library(codetools)
# > showTree(quote(x+sin(y*z)))
# (+ x (sin (* y z)))
