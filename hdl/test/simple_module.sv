// Run arbitrary Python code inside the braces.
`line 2 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
// The final removes the whitespace inserted by em.py after evaluating the python code
`line 3 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0

// To use a value from Python, you can use a tick followed by the variable name
`line 6 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
// myvar = 4

// You can print Python expressions using parentheses
`line 9 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
// myvar+1 = 5, which is pretty neat

`line 11 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
// If you need additional text after the variable, wrap the variable in another plus whitespace
`line 12 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
// port_name = in4_r

// If you want to add an SV compiler directive, use multiple ticks
`line 15 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
`define LYCAN2

module simple_module(
// Control flow constructs use brackets
`line 20 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
    input in0,
`line 20 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
    input in1,
`line 20 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
    input in2,
`line 20 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
    input in3,

`line 24 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
    output outp0,
`line 24 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
    output outp1,
`line 24 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
    output outp2,
`line 24 "/home/matthew/Projects/lycan2/hdl/test/simple_module.svpy" 0
    output outp3,
    output final_output
);

endmodule
