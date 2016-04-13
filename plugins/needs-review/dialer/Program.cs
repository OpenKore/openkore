//Code written by Windham Wong (DrKN)
//RO Dialer through UDP Server
//Version: 22102013

using System;
using System.Text;
using System.IO.Ports;
using System.Net.Sockets;
using System.Net;
using System.Timers;
using System.Text.RegularExpressions;
using System.IO;

namespace Dialer {
    class Program {
        static bool dialFlag = true;
        static Timer timer = new Timer(10000);
        static string telno = "0800892030";
        static string com = "COM1";
        static int port = 9630;
        static SerialPort usb = new SerialPort(com);
        static UdpClient server = null;
        static IPEndPoint IPEP = new IPEndPoint(IPAddress.Any, 0);
        public static void Main(string[] args) {
            byte[] recvMsg;
            string recvStr;
            try { //Read Setting
                Console.WriteLine("Reading config.");
                string path = @"config.txt";
                Regex pattern = new Regex(@"(.*) \= (.*)");
                string[] lines = File.ReadAllLines(path);
                foreach (string line in lines) {
                    if (line.Length != 0 && line[0].Equals(';')) continue; //Skip lines with ';' at the beginning
                    var  matches = pattern.Matches(line);
                    if (matches.Count == 1) {
                        if (matches[0].Groups[1].Value.Trim().Equals("com")) //Assign USB COM
                            com = matches[0].Groups[2].Value.Trim();
                        if (matches[0].Groups[1].Value.Trim().Equals("tel")) //Assign Tel
                            telno = matches[0].Groups[2].Value.Trim();
                        if (matches[0].Groups[1].Value.Trim().Equals("port")) //Assign port
                            port = int.Parse(matches[0].Groups[2].Value.Trim());
                    }
                }
            } catch (Exception exc) {
                Console.WriteLine(exc.ToString());
                Console.ReadKey();
                return;
            }

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
            } catch (Exception exc) {
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
                            usb.Write("ATDT" + telno + ";\r");
                            Console.WriteLine("Dial command sent.");
                        } else
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
            usb.Write("ATH\r");
            timer.Stop();
        }

        private static void usbReceive(object sender, SerialDataReceivedEventArgs e) {
            SerialPort obj = (SerialPort)sender;
            Console.WriteLine("Output: " + obj.ReadExisting().Trim());
        }
    }
}