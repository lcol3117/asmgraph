00000000    1fcd    dec ecx ; this is a comment
00000002    a       sub ebx, ecx
00000004    1dd     xlatb eax
00000006    f2f     movzx edx, eax
00000008    9       imul ecx, edx
0000000A    122     hint_nop7
0000000C    167     syscall
0000000E    123     push ebx
00000010    aa      pop eax
00000012    300     syscall
