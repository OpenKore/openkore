# Guide: How to Find Addresses for recv Hook in Ragnarok Online

## 📺 Video Tutorial

For a visual demonstration of this process, watch the tutorial video below:

[![Video Tutorial](https://img.youtube.com/vi/fUpJr0SUReg/0.jpg)](https://www.youtube.com/watch?v=fUpJr0SUReg)

The video shows step by step how to find the necessary addresses to hook recv in the Ragnarok Online client.

---

## 1. 🎯 MOCK_RECV_PTR_ADDRESS

### Path to find:
1. In IDA Pro, go to **View -> Open Subviews -> Imports**
2. Search for **"ws2_32.dll"**
3. Find the **"recv"** entry
4. Note the IAT (Import Address Table) address: `00EE3710`
5. Double-click on the IAT address in IDA View-A:
   ```
   ________:00EE3710 recv            dd ?                    ; DATA XREF: sub_B7F220+C4↑r
   ```
6. Press **Ctrl+X** to see cross-references
7. Find the reference e.g. `sub_B7F220+C4`:
   ```assembly
   mov     eax, ds:recv
   push    0               ; uType
   push    offset aModuleHookingE ; "Module Hooking Error"
   push    offset aGetprocaddress_0 ; "GetProcAddress(\"recv\") Failed."
   push    0               ; hWnd
   mov     ds:dword_1455BB8, eax    ; <- ADDRESS FOUND
   call    esi ; MessageBoxA
   ```

**Result:** `dword_1455BB8` = **0x1455BB8**

---

## 2. 🎯 MOCK_CLIENT_SUB_ADDRESS

### Path to find:
1. In IDA Pro, go to **View -> Open Subviews -> Imports**
2. Search for **"ws2_32.dll"**
3. Find the **"send"** entry
4. From the address `0x1455BB4` (e.g. send pointer), use **X** to see cross-references
5. Find functions that **use** the send pointer (not those that define it)
6. Example instruction the function will have `mov esi, ds:dword_1455BB4`
7. Find a function like `sub_B7EC50` that performs low-level sending (press F5 in IDA for pseudocode):
   ```cpp
   char __thiscall sub_B7EC50(_DWORD *this)
   {
       // ... network code ...
       v3 = dword_1455BB4(this[1], this[10] + this[9], this[11] - this[10], 0);
       //   ^ calls WinSock send()
   }
   ```
8. **At the end of function `sub_B7EC50`**, look for a block with the line ending with:
   ```assembly
   sub_B7EC50 endp
   ```
9. **Position the cursor** exactly on this line `sub_B7EC50 endp`
10. **Press X** to see cross-references (who calls this function)
11. **Look for "call" type references** in the list that appears, example:
    ```
    Up  c  sub_B7E470+69   call    sub_B7EC50
    Down  c  sub_B7ED50+14   call    sub_B7EC50  
    Down  c  sub_B7ED80+14   call    sub_B7EC50
    Down  c  sub_B7EF50+139  call    sub_B7EC50
    ```
12. **For each function found** (e.g. sub_B7EF50):
    - Press **Ctrl+G** and type the address (e.g. 0xB7EF50)
    - Press **F5** for decompilation
    - Analyze if it's a high-level function that processes packets (you can search for `^` which represents XOR function [normally used for encryption] and `memcpy` or `memset` [normally used for compression])
13. **Identify the correct function** that has these characteristics:
    - `__thiscall` convention (first parameter is `this`)
    - Processes packet data before sending
    - Performs processing (encryption, compression, etc.)
    - Calls `sub_B7EC50` at the end of processing
14. **Example found** `char __thiscall sub_B7EF50(int this, unsigned int a2, _WORD *a3)`

**Result:** `sub_B7EF50` = **0xB7EF50** 

---

## 3. 🎯 MOCK_CRAGCONNECTION_INSTANCE_ADDRESS

### Path to find:
1. In the same function `sub_B7F220` where you found recv, look for class initialization:
   ```assembly
   mov     ds:dword_1455BC0, offset ??_7CRagConnection@@6B@
   ```
2. Use **X** to find all references
3. Look for functions that do `mov eax, offset dword_1455BC0` followed by `retn` (which execute call to this function)
4. Find a block that has the following instructions and connects to it:
   ```assembly
    push    offset dword_1455C40
    call    __Init_thread_footer
    add     esp, 8
    jmp     loc_B7F4EE
   ```
5. The following lines should be something like:
   ```assembly
   sub_B7F4B0 endp
   ```

**Result:** `sub_B7F4B0` = **0xB7F4B0** (instance getter function)

---

## 📋 Discovery Process Summary:

### Recommended search order:
1. **Always start with recv** (IAT from ws2_32.dll)
2. **Follow cross-references** to find where it's used
3. **Analyze the initialization function** to find the CRagConnection class
4. **Find high-level functions** that call low-level ones
5. **Look for getters/singletons** that return class instances

### IDA tools used:
- **View -> Imports** (find IAT)
- **X** (cross-references)
- **F5** (decompilation)
- **Alt+T** (text search)
- **Ctrl+G** (go to address)

### Patterns to identify:
- **recv pointer**: `mov ds:dword_XXXXXX, eax` after `GetProcAddress("recv")`
- **send function**: ragnarok send function calls low-level network function `GetProcAddress("send")`
- **instance getter**: function that returns `&dword_XXXXXX` where the class vtable is located

---

## ⚠️ Important Notes:

1. **Addresses vary between versions** of the Ragnarok client
2. **Use F5 decompilation** to better understand code flow
3. **Doesn't work with Ragexe.exe with Themida** you need to break the protection using [unlicense](https://github.com/ergrelet/unlicense/) 