//Code written by Windham Wong (DrKN)
//RO Dialer through UDP Server

using System;
using System.Text;
using System.IO.Ports;
using System.Net.Sockets;
using System.Net;
using System.Timers;

namespace Dialer {
    class Program {
        static bool dialFlag = true;
        static Timer timer = new Timer(10000);
        static string telno = "37171630";
        static string com = "COM8";
        static int port = 9630;
        static SerialPort usb = new SerialPort(com);
        static UdpClient server = null;
        static IPEndPoint IPEP = new IPEndPoint(IPAddress.Any, 0);
        public static void Main(string[] args) {
            byte[] recvMsg;
            string recvStr;
            try {
                usb.Open();
                Console.WriteLine("Tel. no.: " + telno);
                Console.WriteLine("USB COM: " + com);
                usb.DataReceived += new SerialDataReceivedEventHandler(usbReceive);
                Console.WriteLine("USB initialized.");
                Console.WriteLine("UDP server port: " + port);
                server = new UdpClient(port);
                Console.WriteLine("Server initialized.");
                timer.Elapsed += new ElapsedEventHandler(timeTrigger);
            }catch (Exception exc) {
                Console.WriteLine(exc.ToString());
                Console.ReadKey();
                return;
            }
            while (usb.IsOpen) {
                recvMsg = server.Receive(ref IPEP);
                if (recvMsg != null) {
                    recvStr = Encoding.ASCII.GetString(recvMsg).Trim();
                    //Console.WriteLine(recvStr.ToString());
                    if (recvStr == "dial") {
                        if (dialFlag) {
                            dialFlag = false;
                            timer.Start();
                            usb.Write("ATDT"+telno+";\r");
                            Console.WriteLine("Dial command sent.");
                        }else
                            Console.WriteLine("DialFlag timeout.");
                        
                    } else if (recvStr == "reset") {
                        Console.WriteLine("Reset command sent.");
                        usb.Write("ATZ\r");
                    } else if (recvStr == "hang") {
                        Console.WriteLine("Hang command sent.");
                        usb.Write("ATH\r");
                    }
                }
            }
        }
        
        private static void timeTrigger(object sender, ElapsedEventArgs e) {
            dialFlag = true;
            Console.WriteLine("DialFlag: true");
            timer.Stop();
        }

        private static void usbReceive(object sender, SerialDataReceivedEventArgs e) {
            SerialPort obj = (SerialPort)sender;
            Console.WriteLine("Output: "+obj.ReadExisting().Trim());
        }
    }
}
