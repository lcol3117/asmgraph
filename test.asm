dec ecx ; this is a comment
sub ebx, ecx
xlatb eax
movzx edx, eax
imul ecx, edx
hint_nop7
syscall
mov [esp+0], ebx
pop eax
syscall
