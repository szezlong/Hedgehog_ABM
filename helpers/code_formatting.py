# -*- coding: utf-8 -*-

def format_netlogo_code(code):
    formatted_code = []
    indent_level = 0
    function_indent_level = 0
    in_function = False

    for line in code.split('\n'):
        stripped_line = line.strip()
        if stripped_line:
            if stripped_line.startswith('end'):
                indent_level = function_indent_level
                in_function = False
            elif stripped_line.startswith(']'):
                indent_level -= 1

            if in_function:
                formatted_code.append('  ' * indent_level + stripped_line)
            else:
                formatted_code.append('  ' * function_indent_level + stripped_line)

            if stripped_line.startswith('to '):
                function_indent_level = indent_level
                in_function = True
                indent_level += 1
            elif stripped_line.endswith('['):
                indent_level += 1

    return '\n'.join(formatted_code)

netlogo_code = """
code-here
"""

formatted_code = format_netlogo_code(netlogo_code)
print(formatted_code)