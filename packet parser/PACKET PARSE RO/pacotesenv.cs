using System;
using System.Collections.Generic;
using System.Text;
using SharpPcap;
using PacketDotNet;

namespace PACKET_PARSE_RO
{
    public class PacotesEnv
    {
        public event EventHandler<PacoteEventArgs> PacoteEnviado;

        private Dictionary<int, List<byte[]>> pacotes = new Dictionary<int, List<byte[]>>();

        private string serverIP;
        private int serverPort;

        public PacotesEnv(string serverIP, int serverPort)
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
                            ipPacket.DestinationAddress.ToString() == serverIP &&
                            tcpPacket.DestinationPort == serverPort)
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


                                OnPacoteEnviado(new PacoteEventArgs
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
                Console.WriteLine($"Erro ao processar pacote enviado: {ex.Message}");
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

        protected virtual void OnPacoteEnviado(PacoteEventArgs e)
        {
            PacoteEnviado?.Invoke(this, e);
        }
    }
}