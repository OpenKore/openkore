# Guia: Como Encontrar Endereços para Hook do recv no Ragnarok Online

## 📺 Video Tutorial

Para uma demonstração visual deste processo, assista ao vídeo tutorial abaixo:

[![Tutorial em Vídeo](https://img.youtube.com/vi/fUpJr0SUReg/0.jpg)](https://www.youtube.com/watch?v=fUpJr0SUReg)

O vídeo mostra passo a passo como encontrar os endereços necessários para fazer o hook do recv no cliente do Ragnarök Online.

---

## 1. 🎯 MOCK_RECV_PTR_ADDRESS

### Caminho para encontrar:
1. No IDA Pro, vá para **View -> Open Subviews -> Imports**
2. Procure por **"ws2_32.dll"**
3. Encontre a entrada **"recv"**
4. Anote o endereço da IAT (Import Address Table): `00EE3710`
5. Dê 2 cliques no endereço IAT no IDA View-A:
   ```
   ________:00EE3710 recv            dd ?                    ; DATA XREF: sub_B7F220+C4↑r
   ```
6. Pressione **Ctrl+X** para ver cross-references
7. Encontre a referência por ex `sub_B7F220+C4`:
   ```assembly
   mov     eax, ds:recv
   push    0               ; uType
   push    offset aModuleHookingE ; "Module Hooking Error"
   push    offset aGetprocaddress_0 ; "GetProcAddress(\"recv\") Failed."
   push    0               ; hWnd
   mov     ds:dword_1455BB8, eax    ; <- ENDEREÇO ENCONTRADO
   call    esi ; MessageBoxA
   ```

**Resultado:** `dword_1455BB8` = **0x1455BB8**

---

## 2. 🎯 MOCK_CLIENT_SUB_ADDRESS

### Caminho para encontrar:
1. No IDA Pro, vá para **View -> Open Subviews -> Imports**
2. Procure por **"ws2_32.dll"**
3. Encontre a entrada **"send"**
1. A partir do endereço `0x1455BB4` (ex ponteiro send), use **X** para ver cross-references
2. Encontre funções que **usam** o ponteiro send (não que o definem)
3. Exemplo de instrução que a função terá `mov esi, ds:dword_1455BB4`
4. Encontre uma função como `sub_B7EC50` que faz o envio de baixo nível (apertando F5 no IDA para pseudocódigo):
   ```cpp
   char __thiscall sub_B7EC50(_DWORD *this)
   {
       // ... código de rede ...
       v3 = dword_1455BB4(this[1], this[10] + this[9], this[11] - this[10], 0);
       //   ^ chama send() do WinSock
   }
   ```
5. **No final da função `sub_B7EC50`**, procure por um bloco com a linha que termina com:
   ```assembly
   sub_B7EC50 endp
   ```
6. **Posicione o cursor** exatamente nesta linha `sub_B7EC50 endp`
7. **Pressione X** para ver cross-references (quem chama esta função)
8. **Procure por referências do tipo "call"** na lista que aparece, exemplo:
   ```
   Up  c  sub_B7E470+69   call    sub_B7EC50
   Down  c  sub_B7ED50+14   call    sub_B7EC50  
   Down  c  sub_B7ED80+14   call    sub_B7EC50
   Down  c  sub_B7EF50+139  call    sub_B7EC50
   ```
9.  **Para cada função encontrada** (ex: sub_B7EF50):
    - Pressione **Ctrl+G** e digite o endereço (ex: 0xB7EF50)
    - Pressione **F5** para decompilação
    - Analise se é uma função de alto nível que processa pacotes (pode pesquisar por `^` que representa função XOR [normalmente usada para criptografia] e `memcpy` ou `memset` [normalmente usada para compressão])
10. **Identifique a função correta** que tem estas características:
    - Convenção `__thiscall` (primeiro parâmetro é `this`)
    - Processa dados de pacote antes de enviar
    - Faz processamento (criptografia, compressão, etc.)
    - Chama `sub_B7EC50` no final do processamento
11. **Exemplo encontrado** `char __thiscall sub_B7EF50(int this, unsigned int a2, _WORD *a3)`

**Resultado:** `sub_B7EF50` = **0xB7EF50** 

---

## 3. 🎯 MOCK_CRAGCONNECTION_INSTANCE_ADDRESS

### Caminho para encontrar:
1. Na mesma função `sub_B7F220` onde encontrou o recv, procure pela inicialização da classe:
   ```assembly
   mov     ds:dword_1455BC0, offset ??_7CRagConnection@@6B@
   ```
2. Use **X** e para encontrar todas as referências
3. Procure por funções que fazem `mov eax, offset dword_1455BC0` seguido de `retn` (que executam chamada para essa função)
4. Encontre um bloco que tem as seguintes instruções e liga para esse:
   ```assembly
    push    offset dword_1455C40
    call    __Init_thread_footer
    add     esp, 8
    jmp     loc_B7F4EE
   ```
5. As linhas seguintes devem ser algo como:
   ```assembly
   sub_B7F4B0 endp
   ```

**Resultado:** `sub_B7F4B0` = **0xB7F4B0** (função getter da instância)

---

## 📋 Resumo do Processo de Descoberta:

### Ordem de busca recomendada:
1. **Comece sempre pelo recv** (IAT do ws2_32.dll)
2. **Siga as cross-references** para encontrar onde é usado
3. **Analise a função de inicialização** para encontrar a classe CRagConnection
4. **Encontre funções de alto nível** que chamam as de baixo nível
5. **Procure por getters/singletons** que retornam instâncias da classe

### Ferramentas IDA usadas:
- **View -> Imports** (encontrar IAT)
- **X** (cross-references)
- **F5** (decompilação)
- **Alt+T** (busca textual)
- **Ctrl+G** (ir para endereço)

### Padrões para identificar:
- **recv pointer**: `mov ds:dword_XXXXXX, eax` após `GetProcAddress("recv")`
- **send function**: função send do ragnarok chama função de baixo nível de rede `GetProcAddress("send")`
- **instance getter**: função que retorna `&dword_XXXXXX` onde está a vtable da classe

---

## ⚠️ Notas Importantes:

1. **Os endereços variam entre versões** do cliente Ragnarok
2. **Use decompilação F5** para entender melhor o fluxo do código
3. **Não funciona com Ragexe.exe com Themida** você precisa quebrar a proteção usando [unlicense](https://github.com/ergrelet/unlicense/)
