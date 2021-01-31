00000000    1a    dec ecx ; this is a comment
00000002    c17   sub ebx, ecx
00000004    a0    xlatb eax
00000006    12    movzx edx, eax
00000008    f     imul ecx, edx
0000000A    9ff0c hint_nop7
0000000C    9f    syscall
0000000E    9f    push ebx
00000010    2     pop eax
00000012    a23   syscall
