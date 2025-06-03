using System;
using System.Collections.Generic;
using System.Text;
using SharpPcap;
using PacketDotNet;

namespace PACKET_PARSE_RO
{
    public class PacotesRec
    {
        public event EventHandler<PacoteEventArgs> PacoteRecebido;

        private Dictionary<int, List<byte[]>> pacotes = new Dictionary<int, List<byte[]>>();

        private string serverIP;
        private int serverPort;

        public PacotesRec(string serverIP, int serverPort)
        {
            this.serverIP = serverIP;
            this.serverPort = serverPort;
        }

        public void ProcessarPacote(RawCapture rawCapture)
        {
            try
            {
                Packet packet = Packet.ParsePacket(rawCapture.LinkLayerType, rawCapture.Data);

                if (packet is PacketDotNet.EthernetPacket ethernetPacket)
                {
                    var ipPacket = ethernetPacket.Extract<PacketDotNet.IPv4Packet>();
                    if (ipPacket != null)
                    {
                        var tcpPacket = ipPacket.Extract<PacketDotNet.TcpPacket>();

                        if (tcpPacket != null &&
                            ipPacket.SourceAddress.ToString() == serverIP &&
                            tcpPacket.SourcePort == serverPort)
                        {
                            byte[] payload = tcpPacket.PayloadData;
                            if (payload != null && payload.Length >= 2)
                            {
                                int opcode = payload[0] | (payload[1] << 8);

                                if (!pacotes.ContainsKey(opcode))
                                {
                                    pacotes[opcode] = new List<byte[]>();
                                }

                                pacotes[opcode].Add(payload);

                                OnPacoteRecebido(new PacoteEventArgs
                                {
                                    Opcode = opcode,
                                    Dados = payload,
                                    Timestamp = rawCapture.Timeval.Date
                                });
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Erro ao processar pacote recebido: {ex.Message}");
            }
        }

        public Dictionary<int, List<byte[]>> ObterTodosPacotes()
        {
            return pacotes;
        }

        public List<byte[]> ObterPacotes(int opcode)
        {
            if (pacotes.ContainsKey(opcode))
            {
                return pacotes[opcode];
            }
            return new List<byte[]>();
        }

        public void LimparPacotes()
        {
            pacotes.Clear();
        }

        protected virtual void OnPacoteRecebido(PacoteEventArgs e)
        {
            PacoteRecebido?.Invoke(this, e);
        }
    }

    public class PacoteEventArgs : EventArgs
    {
        public int Opcode { get; set; }
        public byte[] Dados { get; set; }
        public DateTime Timestamp { get; set; }
    }
}