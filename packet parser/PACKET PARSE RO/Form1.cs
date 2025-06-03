using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Xml.Linq;
using SharpPcap;
using PacketDotNet;
using System.Diagnostics;

namespace PACKET_PARSE_RO
{
    public partial class Form1 : Form
    {
        private const string CONFIG_FILE = "config.xml";

        private string defaultServerIP = "35.198.41.33";
        private int defaultServerPort = 10009;

        private List<ICaptureDevice> captureDevices;
        private ICaptureDevice selectedDevice;
        private bool isCapturing = false;

        private PacotesRec pacotesRecebidos;
        private PacotesEnv pacotesEnviados;

        private Dictionary<int, List<int>> packetLengths = new Dictionary<int, List<int>>();
        private Dictionary<int, byte[]> packetExamples = new Dictionary<int, byte[]>();

        private int packetsProcessed = 0;
        private int uniquePackets = 0;
        private int variablePackets = 0;

        private int lastSearchPosition = -1;
        private bool searchDirectionUp = false;
        private string lastSearchText = "";
        private bool lastMatchCase = false;
        private bool lastSearchHex = false;
        private RichTextBox lastActiveRichTextBox = null;
        private SearchForm activeSearchForm = null;
        private RichTextBox[] searchableRichTextBoxes;
        private bool isAutoScrollPaused = false;

        public Form1()
        {
            InitializeComponent();

            pacotesrec.Font = new Font("Consolas", 9F);
            pacotesenv.Font = new Font("Consolas", 9F);

            searchableRichTextBoxes = new RichTextBox[] { pacotesrec, pacotesenv };

            this.KeyPreview = true;
            this.KeyDown += Form1_KeyDown;

            SetupContextMenus();

            this.Text = "ROla Sniff";

            LoadSettings();
            LoadNetworkInterfaces();

            timer1.Interval = 1000;
            timer1.Tick += Timer1_Tick;
            timer1.Start();
        }

        private void Timer1_Tick(object sender, EventArgs e)
        {
            UpdateStats();
        }

        private void LoadSettings()
        {
            try
            {
                if (File.Exists(CONFIG_FILE))
                {
                    XDocument doc = XDocument.Load(CONFIG_FILE);
                    var settings = doc.Element("Settings");

                    if (settings != null)
                    {
                        var serverIP = settings.Element("ServerIP")?.Value;
                        if (!string.IsNullOrEmpty(serverIP))
                        {
                            ipserver.Text = serverIP;
                        }
                        else
                        {
                            ipserver.Text = defaultServerIP;
                        }

                        var serverPort = settings.Element("ServerPort")?.Value;
                        if (!string.IsNullOrEmpty(serverPort) && int.TryParse(serverPort, out int port))
                        {
                            portserver.Text = serverPort;
                        }
                        else
                        {
                            portserver.Text = defaultServerPort.ToString();
                        }

                        var selectedInterface = settings.Element("SelectedInterface")?.Value;
                        if (!string.IsNullOrEmpty(selectedInterface))
                        {
                            LoadNetworkInterfaces(selectedInterface);
                        }
                        else
                        {
                            LoadNetworkInterfaces();
                        }
                    }
                }
                else
                {
                    ipserver.Text = defaultServerIP;
                    portserver.Text = defaultServerPort.ToString();
                    LoadNetworkInterfaces();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Erro ao carregar configurações: {ex.Message}",
                    "Erro", MessageBoxButtons.OK, MessageBoxIcon.Error);

                ipserver.Text = defaultServerIP;
                portserver.Text = defaultServerPort.ToString();
                LoadNetworkInterfaces();
            }
        }

        private void SaveSettings()
        {
            try
            {
                string selectedInterface = string.Empty;
                if (networklist.SelectedIndex >= 0 && networklist.SelectedIndex < captureDevices.Count)
                {
                    selectedInterface = captureDevices[networklist.SelectedIndex].Description;
                }

                XDocument doc = new XDocument(
                    new XElement("Settings",
                        new XElement("ServerIP", ipserver.Text),
                        new XElement("ServerPort", portserver.Text),
                        new XElement("SelectedInterface", selectedInterface)
                    )
                );

                doc.Save(CONFIG_FILE);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Erro ao salvar configurações: {ex.Message}",
                    "Erro", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void LoadNetworkInterfaces(string selectedInterfaceName = null)
        {
            try
            {
                networklist.Items.Clear();
                captureDevices = new List<ICaptureDevice>();

                var devices = CaptureDeviceList.Instance;

                if (devices.Count == 0)
                {
                    networklist.Items.Add("Nenhuma interface de rede encontrada");
                    networklist.Enabled = false;
                    return;
                }

                networklist.Enabled = true;
                int selectedIndex = -1;

                for (int i = 0; i < devices.Count; i++)
                {
                    var device = devices[i];
                    captureDevices.Add(device);

                    string description = !string.IsNullOrEmpty(device.Description)
                        ? device.Description
                        : device.Name;

                    networklist.Items.Add(description);

                    if (selectedInterfaceName != null && device.Description == selectedInterfaceName)
                    {
                        selectedIndex = i;
                    }
                }

                if (networklist.Items.Count > 0)
                {
                    networklist.SelectedIndex = selectedIndex >= 0 ? selectedIndex : 0;
                }
            }
            catch (Exception ex)
            {
                string errorMessage;
                
                if (ex.Message.Contains("wpcap") || ex.Message.Contains("Unable to load DLL"))
                {
                    errorMessage = "NPCAP não encontrado!\n\n" +
                                   "Este aplicativo requer o Npcap para capturar pacotes de rede.\n\n" +
                                   "Para resolver:\n" +
                                   "1. Baixe o Npcap em: https://npcap.com/dist/npcap-1.79.exe\n" +
                                   "2. Execute o instalador como administrador\n" +
                                   "3. Reinicie este aplicativo\n\n" +
                                   $"Erro original: {ex.Message}";
                }
                else
                {
                    errorMessage = $"Erro ao carregar interfaces de rede: {ex.Message}";
                }

                MessageBox.Show(errorMessage, "Erro", MessageBoxButtons.OK, MessageBoxIcon.Error);

                networklist.Items.Add("Erro: Npcap não instalado");
                networklist.Enabled = false;
            }
        }

        private void ipserver_TextChanged(object sender, EventArgs e)
        {
            if (IPAddress.TryParse(ipserver.Text, out _))
            {
                SaveSettings();
            }
        }

        private void portserver_TextChanged(object sender, EventArgs e)
        {
            if (int.TryParse(portserver.Text, out int port) && port > 0 && port < 65536)
            {
                SaveSettings();
            }
        }

        private void networklist_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (networklist.SelectedIndex >= 0 && networklist.SelectedIndex < captureDevices.Count)
            {
                selectedDevice = captureDevices[networklist.SelectedIndex];

                DisplayInterfaceInfo(selectedDevice);

                SaveSettings();
            }
        }

        private void DisplayInterfaceInfo(ICaptureDevice device)
        {
            try
            {
                StringBuilder sb = new StringBuilder();
                sb.AppendLine($"Nome: {device.Name}");
                sb.AppendLine($"Descrição: {device.Description}");

                if (device is SharpPcap.LibPcap.LibPcapLiveDevice livePcapDevice)
                {
                    foreach (var address in livePcapDevice.Addresses)
                    {
                        if (address.Addr != null && address.Addr.ipAddress != null)
                        {
                            sb.AppendLine($"Endereço IP: {address.Addr.ipAddress}");
                        }
                    }
                }

                lblInterfaceInfo.Text = sb.ToString();

                iniciarcap.Enabled = true;
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Erro ao exibir informações da interface: {ex.Message}",
                    "Erro", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void iniciarcap_Click(object sender, EventArgs e)
        {
            try
            {
                if (isCapturing)
                {
                    StopCapture();
                    iniciarcap.Text = "Iniciar Captura";
                    isCapturing = false;

                    networklist.Enabled = true;
                    ipserver.Enabled = true;
                    portserver.Enabled = true;

                    statusLabel.Text = "Captura parada";
                }
                else
                {
                    if (selectedDevice == null)
                    {
                        MessageBox.Show("Selecione uma interface de rede antes de iniciar a captura",
                            "Aviso", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        return;
                    }

                    if (!IPAddress.TryParse(ipserver.Text, out IPAddress serverIP))
                    {
                        MessageBox.Show("Digite um IP de servidor válido",
                            "Aviso", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        return;
                    }

                    if (!int.TryParse(portserver.Text, out int serverPort) ||
                        serverPort <= 0 || serverPort > 65535)
                    {
                        MessageBox.Show("Digite uma porta de servidor válida (1-65535)",
                            "Aviso", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        return;
                    }

                    StartCapture(serverIP.ToString(), serverPort);
                    iniciarcap.Text = "Parar Captura";
                    isCapturing = true;

                    networklist.Enabled = false;
                    ipserver.Enabled = false;
                    portserver.Enabled = false;

                    pacotesrec.Clear();
                    pacotesenv.Clear();

                    packetsProcessed = 0;
                    uniquePackets = 0;
                    variablePackets = 0;

                    UpdateStats();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Erro ao iniciar/parar captura: {ex.Message}",
                    "Erro", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void StartCapture(string serverIP, int serverPort)
        {
            try
            {
                pacotesRecebidos = new PacotesRec(serverIP, serverPort);
                pacotesEnviados = new PacotesEnv(serverIP, serverPort);

                pacotesRecebidos.PacoteRecebido += PacotesRecebidos_PacoteRecebido;
                pacotesEnviados.PacoteEnviado += PacotesEnviados_PacoteEnviado;

                selectedDevice.Open(DeviceModes.Promiscuous, 1000);

                string filter = $"tcp and host {serverIP} and port {serverPort}";
                selectedDevice.Filter = filter;

                selectedDevice.OnPacketArrival += Device_OnPacketArrival;

                selectedDevice.StartCapture();

                statusLabel.Text = "Captura iniciada";
            }
            catch (Exception ex)
            {
                throw new Exception($"Erro ao iniciar captura: {ex.Message}", ex);
            }
        }

        private void Device_OnPacketArrival(object sender, PacketCapture e)
        {
            try
            {
                RawCapture rawCapture = e.GetPacket();

                pacotesRecebidos.ProcessarPacote(rawCapture);
                pacotesEnviados.ProcessarPacote(rawCapture);

                packetsProcessed++;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Erro ao processar pacote: {ex.Message}");
            }
        }

        private void StopCapture()
        {
            try
            {
                if (selectedDevice != null && selectedDevice.Started)
                {
                    selectedDevice.StopCapture();
                    selectedDevice.Close();

                    selectedDevice.OnPacketArrival -= Device_OnPacketArrival;

                    if (pacotesRecebidos != null)
                        pacotesRecebidos.PacoteRecebido -= PacotesRecebidos_PacoteRecebido;

                    if (pacotesEnviados != null)
                        pacotesEnviados.PacoteEnviado -= PacotesEnviados_PacoteEnviado;
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Erro ao parar captura: {ex.Message}", ex);
            }
        }

        private void PacotesRecebidos_PacoteRecebido(object sender, PacoteEventArgs e)
        {
            this.BeginInvoke((MethodInvoker)delegate
            {
                AddPacketToList(e.Opcode, e.Dados.Length, e.Dados);

                FormatarPacote(pacotesrec, e.Opcode, e.Dados, e.Timestamp, "RECV");

                if (!isAutoScrollPaused)
                {
                    pacotesrec.ScrollToCaret();
                }

                UpdateStats();
            });
        }

        private void PacotesEnviados_PacoteEnviado(object sender, PacoteEventArgs e)
        {
            this.BeginInvoke((MethodInvoker)delegate
            {
                AddPacketToList(e.Opcode, e.Dados.Length, e.Dados);

                FormatarPacote(pacotesenv, e.Opcode, e.Dados, e.Timestamp, "SEND");

                if (!isAutoScrollPaused)
                {
                    pacotesenv.ScrollToCaret();
                }

                UpdateStats();
            });
        }

        private void AddPacketToList(int opcode, int length, byte[] dados)
        {
            bool isNewPacket = false;

            if (!packetLengths.ContainsKey(opcode))
            {
                packetLengths[opcode] = new List<int>();
                isNewPacket = true;
            }

            if (!packetLengths[opcode].Contains(length))
            {
                packetLengths[opcode].Add(length);
            }

            if (!packetExamples.ContainsKey(opcode))
            {
                packetExamples[opcode] = dados;
            }

            if (isNewPacket)
            {
                UpdatePacketListView();
            }
        }

        private void UpdatePacketListView()
        {
            try
            {
                packetListView.Items.Clear();

                uniquePackets = 0;
                variablePackets = 0;

                foreach (var entry in packetLengths.OrderBy(e => e.Key))
                {
                    int opcode = entry.Key;
                    List<int> lengths = entry.Value;

                    string packetType;
                    int packetLength;

                    if (lengths.Distinct().Count() == 1)
                    {
                        packetType = "Fixo";
                        packetLength = lengths[0];
                        uniquePackets++;
                    }
                    else
                    {
                        packetType = "Variável";
                        packetLength = -1;
                        variablePackets++;
                    }

                    ListViewItem item = new ListViewItem(opcode.ToString("X4"));
                    item.SubItems.Add(packetLength.ToString());
                    item.SubItems.Add(packetType);
                    item.SubItems.Add(lengths.Count.ToString());

                    if (packetType == "Variável")
                    {
                        item.BackColor = Color.LightYellow;
                    }

                    packetListView.Items.Add(item);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Erro ao atualizar lista de pacotes: {ex.Message}");
            }
        }

        private void FormatarPacote(RichTextBox richTextBox, int opcode, byte[] dados, DateTime timestamp, string direction)
        {
            int startIndex = richTextBox.TextLength;

            richTextBox.AppendText($"[{timestamp:HH:mm:ss.fff}] {direction} Opcode: 0x{opcode:X4} | Tamanho: {dados.Length} bytes");
            richTextBox.AppendText(Environment.NewLine);

            richTextBox.Select(startIndex, richTextBox.TextLength - startIndex);
            richTextBox.SelectionFont = new Font(richTextBox.Font, FontStyle.Bold);

            int bytesPerLine = 16;

            for (int i = 0; i < dados.Length; i += bytesPerLine)
            {
                startIndex = richTextBox.TextLength;
                richTextBox.AppendText($"{i:X4}:  ");
                richTextBox.Select(startIndex, richTextBox.TextLength - startIndex);
                richTextBox.SelectionColor = Color.Blue;
                richTextBox.SelectionFont = new Font(richTextBox.Font, FontStyle.Bold);

                startIndex = richTextBox.TextLength;
                for (int j = 0; j < bytesPerLine; j++)
                {
                    if (i + j < dados.Length)
                        richTextBox.AppendText($"{dados[i + j]:X2} ");
                    else
                        richTextBox.AppendText("   ");

                    if (j == 7)
                        richTextBox.AppendText(" ");
                }
                richTextBox.Select(startIndex, richTextBox.TextLength - startIndex);
                richTextBox.SelectionColor = Color.Green;
                richTextBox.SelectionFont = new Font(richTextBox.Font, FontStyle.Bold);

                richTextBox.AppendText(" | ");

                startIndex = richTextBox.TextLength;
                for (int j = 0; j < bytesPerLine; j++)
                {
                    if (i + j < dados.Length)
                    {
                        char c = (char)dados[i + j];
                        if (c < 32 || c > 126)
                            richTextBox.AppendText(".");
                        else
                            richTextBox.AppendText(c.ToString());
                    }
                }
                richTextBox.Select(startIndex, richTextBox.TextLength - startIndex);
                richTextBox.SelectionColor = Color.Red;
                richTextBox.SelectionFont = new Font(richTextBox.Font, FontStyle.Bold);

                richTextBox.AppendText(Environment.NewLine);
            }

            startIndex = richTextBox.TextLength;
            richTextBox.AppendText(Environment.NewLine);
            richTextBox.AppendText("Dados brutos (hex):");
            richTextBox.AppendText(Environment.NewLine);

            richTextBox.Select(startIndex, richTextBox.TextLength - startIndex);
            richTextBox.SelectionFont = new Font(richTextBox.Font, FontStyle.Bold);
            richTextBox.SelectionColor = Color.Purple;

            startIndex = richTextBox.TextLength;
            foreach (byte b in dados)
            {
                richTextBox.AppendText($"{b:X2}");
            }

            richTextBox.Select(startIndex, richTextBox.TextLength - startIndex);
            richTextBox.SelectionFont = new Font(richTextBox.Font, FontStyle.Bold);
            richTextBox.SelectionColor = Color.Orange;

            richTextBox.AppendText(Environment.NewLine);
            richTextBox.AppendText(Environment.NewLine);

            richTextBox.SelectionStart = richTextBox.TextLength;
            richTextBox.SelectionLength = 0;
            richTextBox.SelectionColor = richTextBox.ForeColor;
            richTextBox.SelectionFont = richTextBox.Font;
        }

        private void UpdateStats()
        {
            lblTotalPackets.Text = $"{packetsProcessed}";
            lblUniquePackets.Text = $"{uniquePackets}";
            lblVariablePackets.Text = $"{variablePackets}";
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (isCapturing)
            {
                try
                {
                    StopCapture();
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Erro ao parar captura durante fechamento: {ex.Message}");
                }
            }

            base.OnFormClosing(e);
        }

        private void Form1_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.Control && e.KeyCode == Keys.F)
            {
                e.SuppressKeyPress = true;
                ShowSearchDialog();
            }
        }

        private void ShowSearchDialog()
        {
            isAutoScrollPaused = true;

            if (pacotesrec.Focused)
            {
                lastActiveRichTextBox = pacotesrec;
            }
            else if (pacotesenv.Focused)
            {
                lastActiveRichTextBox = pacotesenv;
            }
            else
            {
                lastActiveRichTextBox = pacotesrec;
                pacotesrec.Focus();
            }

            if (activeSearchForm != null && !activeSearchForm.IsDisposed)
            {
                activeSearchForm.Focus();
                return;
            }

            activeSearchForm = new SearchForm();
            activeSearchForm.SearchNext += SearchForm_SearchNext;

            activeSearchForm.FormClosed += (s, e) =>
            {
                activeSearchForm = null;
                isAutoScrollPaused = false;
            };

            if (pacotesrec.Focused)
            {
                activeSearchForm.SearchArea = 0;
                lastActiveRichTextBox = pacotesrec;
            }
            else if (pacotesenv.Focused)
            {
                activeSearchForm.SearchArea = 1;
                lastActiveRichTextBox = pacotesenv;
            }
            else
            {
                activeSearchForm.SearchArea = 0;
                lastActiveRichTextBox = pacotesrec;
            }

            if (!string.IsNullOrEmpty(lastSearchText))
            {
                int count = CountOccurrences(lastActiveRichTextBox.Text, lastSearchText, lastMatchCase);
                activeSearchForm.UpdateOccurrencesCount(count);
            }

            activeSearchForm.Show(this);
        }

        private void SearchForm_SearchNext(object sender, EventArgs e)
        {
            if (activeSearchForm == null) return;

            lastActiveRichTextBox = searchableRichTextBoxes[activeSearchForm.SearchArea];

            lastSearchText = activeSearchForm.SearchText;
            lastMatchCase = activeSearchForm.MatchCase;
            searchDirectionUp = activeSearchForm.SearchUp;
            lastSearchHex = activeSearchForm.SearchHex;

            if (lastSearchHex)
            {
                lastSearchText = ConvertHexToSearchPattern(lastSearchText);
                if (string.IsNullOrEmpty(lastSearchText)) return;
            }

            int count = CountOccurrences(lastActiveRichTextBox.Text, lastSearchText, lastMatchCase);
            activeSearchForm.UpdateOccurrencesCount(count);

            FindNextOccurrence();
        }

        private int CountOccurrences(string text, string searchText, bool matchCase)
        {
            if (string.IsNullOrEmpty(text) || string.IsNullOrEmpty(searchText))
                return 0;

            int count = 0;
            int position = 0;

            StringComparison comparison = matchCase ?
                StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;

            while ((position = text.IndexOf(searchText, position, comparison)) != -1)
            {
                count++;
                position += searchText.Length;
            }

            return count;
        }

        private string ConvertHexToSearchPattern(string hexInput)
        {
            try
            {
                hexInput = hexInput.Replace(" ", "").Replace("-", "").Replace("0x", "").Replace("0X", "");

                if (!System.Text.RegularExpressions.Regex.IsMatch(hexInput, @"^[0-9A-Fa-f]+$"))
                {
                    MessageBox.Show("Valor hexadecimal inválido. Use apenas dígitos hexadecimais (0-9, A-F).",
                        "Erro de busca", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return "";
                }

                if (hexInput.Length % 2 != 0)
                {
                    hexInput = "0" + hexInput;
                }

                StringBuilder pattern = new StringBuilder();
                for (int i = 0; i < hexInput.Length; i += 2)
                {
                    string hexPair = hexInput.Substring(i, 2);
                    pattern.Append($"{hexPair} ");
                }

                if (pattern.Length > 0)
                    pattern.Length--;

                return pattern.ToString().ToUpper();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Erro ao processar valor hexadecimal: {ex.Message}",
                    "Erro de busca", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return "";
            }
        }

        private void FindNextOccurrence()
        {
            if (lastActiveRichTextBox == null || string.IsNullOrEmpty(lastSearchText))
                return;

            int startPosition = lastActiveRichTextBox.SelectionStart;
            string text = lastActiveRichTextBox.Text;

            int nextPosition = -1;

            if (searchDirectionUp)
            {
                if (startPosition > 0)
                {
                    int searchStart = Math.Max(0, startPosition - 1);
                    nextPosition = lastMatchCase
                        ? text.LastIndexOf(lastSearchText, searchStart, StringComparison.Ordinal)
                        : text.LastIndexOf(lastSearchText, searchStart, StringComparison.OrdinalIgnoreCase);

                    if (nextPosition == -1)
                    {
                        DialogResult result = MessageBox.Show(
                            "Texto não encontrado. Deseja continuar a busca do final do texto?",
                            "Busca", MessageBoxButtons.YesNo, MessageBoxIcon.Question);

                        if (result == DialogResult.Yes)
                        {
                            nextPosition = lastMatchCase
                                ? text.LastIndexOf(lastSearchText, text.Length - 1, StringComparison.Ordinal)
                                : text.LastIndexOf(lastSearchText, text.Length - 1, StringComparison.OrdinalIgnoreCase);
                        }
                    }
                }
            }
            else
            {
                startPosition = startPosition + lastActiveRichTextBox.SelectionLength;

                if (startPosition >= text.Length)
                    startPosition = 0;

                nextPosition = lastMatchCase
                    ? text.IndexOf(lastSearchText, startPosition, StringComparison.Ordinal)
                    : text.IndexOf(lastSearchText, startPosition, StringComparison.OrdinalIgnoreCase);

                if (nextPosition == -1 && startPosition > 0)
                {
                    DialogResult result = MessageBox.Show(
                        "Texto não encontrado. Deseja continuar a busca do início?",
                        "Busca", MessageBoxButtons.YesNo, MessageBoxIcon.Question);

                    if (result == DialogResult.Yes)
                    {
                        nextPosition = lastMatchCase
                            ? text.IndexOf(lastSearchText, 0, StringComparison.Ordinal)
                            : text.IndexOf(lastSearchText, 0, StringComparison.OrdinalIgnoreCase);
                    }
                }
            }

            if (nextPosition != -1)
            {
                lastActiveRichTextBox.Focus();
                lastActiveRichTextBox.Select(nextPosition, lastSearchText.Length);

                lastActiveRichTextBox.SelectionBackColor = Color.Yellow;
                lastActiveRichTextBox.SelectionColor = Color.Black;

                lastActiveRichTextBox.ScrollToCaret();
                lastSearchPosition = nextPosition;
            }
            else
            {
                MessageBox.Show("Texto não encontrado.", "Busca",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        private void SetupContextMenus()
        {
            ContextMenuStrip menuRec = new ContextMenuStrip();
            ToolStripMenuItem searchItem = new ToolStripMenuItem("Buscar (Ctrl+F)");
            searchItem.Click += (sender, e) => ShowSearchDialog();
            menuRec.Items.Add(searchItem);
            pacotesrec.ContextMenuStrip = menuRec;

            ContextMenuStrip menuEnv = new ContextMenuStrip();
            ToolStripMenuItem searchItem2 = new ToolStripMenuItem("Buscar (Ctrl+F)");
            searchItem2.Click += (sender, e) => ShowSearchDialog();
            menuEnv.Items.Add(searchItem2);
            pacotesenv.ContextMenuStrip = menuEnv;
        }
    }
}