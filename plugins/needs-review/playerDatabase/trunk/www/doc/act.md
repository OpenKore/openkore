# Especificação do formato de arquivo Ragnarok Action

- Autor: Luis Henrique(HwapX)
- Licença: Public Documentation License ([http://www.openoffice.org/licenses/PDL.html]())
- Contribuidores
    - KeplerBR
	- Sergio OpenRagnarok
- Outras Fontes
    - [http://mist.in/gratia/ro/spr/ActFileFormatFix.html]()
    - OpenRagnarok([http://www.open-ragnarok.org/]())
    - Wikipedia([http://www.wikipedia.org/]())
- Download:
	- PDF [http://url.com]()
	- ?
- Lançamento: 20/06/2013
- Ultima Modificação: 20/06/2013
- Versão: 0.1

## Introdução

### Licença

O conteúdo deste documento está sujeito aos termos da licença [Public Document License](http://www.openoffice.org/licenses/PDL.html), você somente deve utiliza-la caso esteja de acordo com os termos da licença.

Esta **não é uma documentação oficial** e foi escrita com base em especificações e códigos de terceiros(Todos devidamente citados em Fontes).

A licença cobre somente a documentação e não o formato sobre o qual fala, este está sobre os termos de licença impostos pela [GRAVITY](http://www.gravity.co.kr/) empresa responsável pelo jogo.

### Abstração

Esse documento contém a descrição do formato binário do Ragnarok Action, o qual é usado para armazenar as animações dos objetos do jogo.

### Termos, símbolos e formatação usada

#### Referencias

[Exemplo](#)

#### Números

São exibidos em diversos formatos.

- Decimal

    Não tem nenhuma marcação `1024`

- Hexadecimal

    Prefixados com `0x`, exemplo `0x21`

#### Dados

Pequenos trechos do arquivo são mostrados da seguinte forma `41 43 05 02` onde cada byte é separado por um espaço.

Grandes trechos são assim.

> **00000000** 41 43 05 02 68 00 47 00 D8 03 47 00 04 00 00 00 03 00 **AC..h.G...G.......**

Offset seguido pelos dados em hexadecimal e por fim sua representação em texto.  
*Nota*: O Ponto(**.**) é utilizado para indicar caracteres não imprimiveis.

#### Termos
- *Não Usado*

    Indica que o dados não são mais utilizados e devem ser ignorados na leitura e preenchidos com zeros na escrita.

- *Desconhecido*

    Descreve campos que tem dados, porem com função desconhecida, normalmente estes campos devem manter os mesmos valores descritos.

- *Offset*

    Indica a localização de um valor dentro do arquivo.

#### Campos de dados

Quando citado fora de um exemplo de código os tipos de dados são representados da seguinte forma.

**nome**: __tipo__*(tamanho)[quantidade]* = *valor*

`nome` e `tipo` são obrigatorios, `tamanho` só é utilizado em strings.

#### Tipos de dados

- string
    Representa textos.
- byte
    Representa um inteiro de 8 bits.
- short
    Representa inteiros de 16 bits.
- int
    Representa inteiros de 32 bits.
- float
    Representa um numero com ponto fluante de 32 bits.
- estruturas
    Veja estruturas.

#### Estruturas

Estruturas são um conjunto de campos encapsulados, normalmente utilizada para encapsular dados relacionados em algo mais abstrato, são representadas da seguinte forma.

- **nome**
    - **campo**
    - **campo**

Elas podem ter um numero indefinido de campos, também pode ter outras estruturas aninhadas como se fosse um campo, nesse caso o `nome` delas também é o tipo do campo.  
Também é possivel utilizar o valor de outro campo acima para setar o tamanho e/ou quantidade de outro campo.

- **Header**
    - **magic**: string[2] = "AC"
    - **version**
        - **minor**: byte
        - **major**: byte
    - **ActionCount**: short
    - **Unknown**: byte[10]
    - **Actions**: Action[ActionCount]

É possivel também 


#### Exemplos de código

São exemplos de código em linguagens variadas
```c
fseek(handle, 10, SEEK_CUR);
```

## Armazenamento

### Extensão

O arquivo tem a extensão `.act`, porem também pode ser identificado pelos 2 primeiros bytes(aka Magic Header).

### Ordenação dos bytes

A ordem dos bytes indica como um dado é armazenado, existem dois tipos de ordenação Little-Endian e Big-Endian.

- Little-Endian

    Neste formato os números são armazenados com o bit menos significativo á esquerda.  
    Exemplo: `0x43F4` é armazenado como `F4 43`

- Big-Endian

    Neste formato  os números são armazenados com o bit menos significativo á direita.  
    Exemplo: `0x43F4` é armazenado como `43 F4`

Este formato de arquivo armazena os dados em Little-Endian [http://en.wikipedia.org/wiki/Endianness]().


## Formato

### Versão

Existem varias versões deste arquivo, infelizmente nem todas estão documentadas aqui por falta de informações sobre elas.

Até o momento pelo que se pode constatar a cada versão campos são adicionados, porem nunca são removidos ou tem sua função alterada.

Esse documento só descreve o formato da versão `2.0` á `2.5`.

### Estruturas

O arquivo é constituído de varias estruturas que serão citadas abaixo.

Observações:

A ordem que as estruturas aparecem  não é necessariamente a ordem em que você vai ler elas no arquivo.

Alguns campos das estruturas só existem em determinadas versões

Estruturas que se repetem somente uma vez e são autoexplicativas estão aninhadas, leve isso em consideração durante leitura.

Algumas estruturas definidas aqui não estão confirmadas como corretas e os dados quando lidos não fazem muito sentido, isso pode ser porque elas não são mais utilizadas e estão com dados arbitrários ou porque estão realmente incorretas, porem todas tem o tamanho correto permitindo a leitura sem desvios.

#### Header

Contém as informações básicas para a leitura do arquivo como versão e quantidade de Actions contidas nele.

- **Magic**: string(2) = "AC"  
    Usado para identificar o arquivo
- **Version**:
    - **Minor**: byte
    - **Major**: byte
- **ActionCount**: short
    Quantidade de Actions no arquivo
- **Unknown**: byte[10]
- **Actions**: Action[ActionCount]

#### Coordenates

Definida do código do OpenRagnarok em outras especificações é tratada como desconhecida.

- **Left**: int
- **Top**: int
- **Right**: int
- **Bottom**: int

#### Action

- **FrameCount**: int32
- **Frames**: Frame[FrameCount]

#### Frame
- Coord_1: Coordenates
    > *Desconhecido*
- Coord_2: Coordenates
    > *Desconhecido*
- Sprite: uint32
    > Indica a quantidade de Sprites utilizados neste Frame
- Sprites: Sprite[Sprite count]
- *if Header.Version.Major >= 2*
- Sound index: int32
- *if Header.Version.Minor >= 3*
- Attach Point count: int32
- Attach Points: AttachPoint[Attach Point count]

#### Sprite

Contém as informações necessárias para montar o Frame.

- X: int32
- Y: int32
- Sprite: int32
- Mirror: boolean(int32)
- *if Header.Version.Major >= 2
- Color: int32
    - Red: byte
    - Green: byte
    - Blue: byte
    - Alpha: byte
- Scale
    - X: float
    - *if Header.Version.Minor >= 4*
    - Y: float
    - Angle: int32
    - Type: int32
- AttachPoint
- Unknown: int32
- X: int32
- Y: int32
- Attributes: int32

#### Sounds

Armazena o caminho dos arquivos de som tocados na animação.

O nome dos arquivos está codificado em gb18030.

- Count: int32
- Filenames: char[Count][40]

#### Delays: float[Header.ActionCount]

## Desenho

### Posicionamento


### Escala
