using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Text;

namespace PACKET_PARSE_RO
{
    public class ProcessManager
    {
        private List<ProcessInfo> networkProcesses = new List<ProcessInfo>();

        public class ProcessInfo
        {
            public int ProcessId { get; set; }
            public string ProcessName { get; set; }
            public string MainWindowTitle { get; set; }
            public List<TcpConnectionInfo> Connections { get; set; } = new List<TcpConnectionInfo>();

            public override string ToString()
            {
                string displayName = string.IsNullOrEmpty(MainWindowTitle) ? ProcessName : MainWindowTitle;
                return $"{ProcessId} - {displayName}";
            }
        }

        public class TcpConnectionInfo
        {
            public IPEndPoint LocalEndPoint { get; set; }
            public IPEndPoint RemoteEndPoint { get; set; }
            public TcpState State { get; set; }

            public override string ToString()
            {
                return $"{LocalEndPoint} -> {RemoteEndPoint} ({State})";
            }
        }

        public ProcessManager()
        {
            RefreshProcessList();
        }

        public List<ProcessInfo> GetNetworkProcesses()
        {
            return networkProcesses;
        }

        public void RefreshProcessList()
        {
            try
            {
                networkProcesses.Clear();
                Dictionary<int, ProcessInfo> processesByPid = new Dictionary<int, ProcessInfo>();

                Process[] processes = Process.GetProcesses();
                foreach (Process process in processes)
                {
                    try
                    {
                        processesByPid[process.Id] = new ProcessInfo
                        {
                            ProcessId = process.Id,
                            ProcessName = process.ProcessName,
                            MainWindowTitle = process.MainWindowTitle
                        };
                    }
                    catch {}
                }

                IPGlobalProperties properties = IPGlobalProperties.GetIPGlobalProperties();
                TcpConnectionInformation[] connections = properties.GetActiveTcpConnections();

                ProcessStartInfo psi = new ProcessStartInfo("netstat", "-ano");
                psi.RedirectStandardOutput = true;
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;

                Process netstatProcess = new Process();
                netstatProcess.StartInfo = psi;
                netstatProcess.Start();

                string output = netstatProcess.StandardOutput.ReadToEnd();
                netstatProcess.WaitForExit();

                string[] lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);

                foreach (string line in lines)
                {
                    if (line.Trim().StartsWith("TCP", StringComparison.OrdinalIgnoreCase))
                    {
                        string[] parts = line.Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                        if (parts.Length >= 5)
                        {
                            string lastPart = parts[parts.Length - 1];
                            if (int.TryParse(lastPart, out int pid) && processesByPid.ContainsKey(pid))
                            {
                                string localAddressStr = parts[1];
                                string remoteAddressStr = parts[2];
                                string stateStr = parts[3];

                                try
                                {
                                    string[] localParts = localAddressStr.Split(':');
                                    if (localParts.Length == 2)
                                    {
                                        string localIp = localParts[0];
                                        if (int.TryParse(localParts[1], out int localPort))
                                        {
                                            string[] remoteParts = remoteAddressStr.Split(':');
                                            if (remoteParts.Length == 2)
                                            {
                                                string remoteIp = remoteParts[0];
                                                if (int.TryParse(remoteParts[1], out int remotePort))
                                                {
                                                    TcpState state;
                                                    if (Enum.TryParse(stateStr, true, out state))
                                                    {
                                                        TcpConnectionInfo connection = new TcpConnectionInfo
                                                        {
                                                            LocalEndPoint = new IPEndPoint(IPAddress.Parse(localIp), localPort),
                                                            RemoteEndPoint = new IPEndPoint(IPAddress.Parse(remoteIp), remotePort),
                                                            State = state
                                                        };

                                                        processesByPid[pid].Connections.Add(connection);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                catch
                                {
                                }
                            }
                        }
                    }
                }

                foreach (var processInfo in processesByPid.Values)
                {
                    if (processInfo.Connections.Count > 0)
                    {
                        networkProcesses.Add(processInfo);
                    }
                }

                networkProcesses = networkProcesses.OrderBy(p => p.ProcessId).ToList();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Erro ao atualizar lista de processos: {ex.Message}");
                throw;
            }
        }

        public ProcessInfo GetProcessById(int pid)
        {
            return networkProcesses.FirstOrDefault(p => p.ProcessId == pid);
        }

        public bool IsProcessActive(int pid)
        {
            var process = GetProcessById(pid);
            return process != null && process.Connections.Count > 0;
        }
    }
}