# Python Preprocessor

This project uses the prepro script powered by em.py as a preprocessor step before the standard
SystemVerilog preprocessor. This allows for more powerful meta-programming of SystemVerilog using
Python.

## Syntax

All preprocessing is delimited with backticks. See below for sample syntax

### Input
```systemverilog
// Run arbitrary Python code inside the braces if you don't want it to print anything.
// The final ` removes the whitespace inserted by em.py after evaluating the Python
`{myvar = 4}`

// To use a value from Python, you can use a tick followed by the variable name
// myvar = `myvar

// You can print Python expressions using parentheses
// myvar+1 = `(myvar+1), which is pretty neat

// If you need additional text after the variable, wrap the variable in another ` plus whitespace
// port_name = in`myvar` _r

// If you want to render a tick to the output file, use two ticks
``define LYCAN2

module simple_module(
// Control flow constructs use brackets
`[for i in range(myvar)]`
    input in`i,
`[end for]`

`[for i in range(myvar)]`
    output outp`i,
`[end for]`
);
```

### Output
```systemverilog
// Run arbitrary Python code inside the braces.
// The final removes the whitespace inserted by em.py after evaluating the python code

// To use a value from Python, you can use a tick followed by the variable name
// myvar = 4

// You can print Python expressions using parentheses
// myvar+1 = 5 , which is pretty neat

// If you need additional text after the variable, wrap the variable in another plus whitespace
// port_name = in4_r

// If you want to add an SV compiler directive, use multiple ticks
`define LYCAN2

module simple_module(
// Control flow constructs use brackets
    input in0,
    input in1,
    input in2,
    input in3,

    output outp0,
    output outp1,
    output outp2,
    output outp3,
);
```

## Other Notes

The prepro script currently has two functions, process and processDebug. The difference is that
processDebug prints SV `line` directives above every prepro macro that prints output for use with
linters, etc.
