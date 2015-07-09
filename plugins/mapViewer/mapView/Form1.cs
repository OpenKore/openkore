using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Diagnostics;
using System.Text.RegularExpressions;
using System.IO;

namespace mapView {
    public partial class Form1 : Form {
        private int processID = 0;
        private int mapHeight;
        private Process processHandle;
        
        public Form1() {
            InitializeComponent();
        }

        private void Form1_Resize(object sender, EventArgs e) {
            this.groupBox1.Width = this.Width - 15;
            this.processGroup.Width = this.Width - 15;
            this.mapBox.Width = this.Width - 15;
            this.mapBox.Height = this.Height - 150;
        }

        private void Form1_Shown(object sender, EventArgs e) {
            this.groupBox1.Width = this.Width - 15;
            this.processGroup.Width = this.Width - 15;
            getProcesses();
        }

        private void getProcesses() {
            Regex reg = new Regex(@"(.{1,24}):\s{1,3}B(\d{1,3})\s{1,3}\(\d{1,3}\.\d{1,2}\%\),\s{1,3}J\d{1,3}\s{1,3}\(\d{1,3}\.\d{1,2}\%\)\s{1,3}:\s{1,3}w\d{1,3}\%\s{1,3}:\s{1,3}\d{1,3},\d{1,3}\s{1,3}(.{3,15})\s{1,3}-\s{1,3}OpenKore");
            Process[] processList = Process.GetProcesses();
            processListBox.Items.Clear();

            updateTimer.Enabled = false;
            foreach (Process ps in processList) {
                if (ps.MainWindowTitle == "") continue; //Skip blank title
                Match match = reg.Match(ps.MainWindowTitle); //Match regex
                if (match.Success) {
                    processListBox.Items.Add(match.Groups[1].Value + " (" + match.Groups[2].Value + ") <" + match.Groups[3].Value + "> [" + ps.Id + "]");
                }
            }
            if (processListBox.Items.Count == 0) {
                processListBox.Items.Add("找不到OpenKore程序。");
                processListBox.SelectedIndex = 0;
            }
        }

        private void button1_Click(object sender, EventArgs e) {
            getProcesses();
        }

        private void updateTimer_Tick(object sender, EventArgs e) {
            if (processID == 0) {
                updateTimer.Enabled = false;
                return;
            }
            if (updateTimer.Interval == 100)
                updateTimer.Interval = 1000;
            try {
                processHandle = Process.GetProcessById(processID);
            } catch (Exception) {
                processListBox.Items.Clear();
                processListBox.Items.Add("提取程序資訊錯誤！ [" + processID + "]");
                processListBox.SelectedIndex = 0;
                updateTimer.Enabled = false;
                return;
            }
            Regex reg = new Regex(@"(.{1,24}):\s{1,3}B(\d{1,3})\s{1,3}\(\d{1,3}\.\d{1,2}\%\),\s{1,3}J\d{1,3}\s{1,3}\(\d{1,3}\.\d{1,2}\%\)\s{1,3}:\s{1,3}w\d{1,3}\%\s{1,3}:\s{1,3}(\d{1,3}),(\d{1,3})\s{1,3}(.{3,15})\s{1,3}-\s{1,3}OpenKore");
            Match match = reg.Match(processHandle.MainWindowTitle);
            if (!match.Success) {
                return;
            }
            this.Text = match.Groups[1].Value + " <" + match.Groups[5].Value + "> - OpenKore 地圖顯示器";
            int posX, posY;
            int.TryParse(match.Groups[3].Value, out posX);
            int.TryParse(match.Groups[4].Value, out posY);
            String fldPath = "fields/" + match.Groups[5].Value + ".fld";
            mapStr.Text = "Map: " + match.Groups[5].Value;
            xStr.Text = "X: " + posX;
            yStr.Text = "Y: " + posY;
            if (File.Exists(fldPath)) {
                byte[] fldData = File.ReadAllBytes(fldPath);
                int w = BitConverter.ToInt16(fldData, 0);
                int h = BitConverter.ToInt16(fldData, 2);
                mapHeight = h;
                if (w + 15 > 330)
                    this.Width = w + 15;
                else
                    this.Width = 330;
                if (h + 150 > 427)
                    this.Height = h + 150;
                else
                    this.Height = 427;
                byte[,] mapData = new byte[h, w];
                Bitmap mapImg = new Bitmap(w, h);
                using (var img = Graphics.FromImage(mapImg))
                    img.FillRectangle(Brushes.White, 0, 0, w, h); //Draw white bg (Walkable)
                for (int x = 0; x < w; x++)
                    for (int y = 0; y < h; y++)
                        if (fldData[y * w + x + 3] != 0x0)
                            mapImg.SetPixel(x, h - y - 1, Color.DarkGray); //Draw Walls (Non-walkable)
                using (var img = Graphics.FromImage(mapImg))
                    img.FillEllipse(Brushes.Red, posX - 4, h - posY - 1 - 4, 8, 8); //Draw position
                mapBox.Image = mapImg;
            } else
                mapBox.Image = null; //Clear image
        }

        private void processListBox_SelectedIndexChanged(object sender, EventArgs e) {
            if (processListBox.SelectedIndex == -1)
                return;

            String txt = processListBox.SelectedItem.ToString();
            Regex reg = new Regex(@"<.{3,15}> \[(\d{3,6})\]");
            Match match = reg.Match(txt); //Match regex
            if (match.Success)
                Int32.TryParse(match.Groups[1].Value, out processID);
            updateTimer.Interval = 100;
            updateTimer.Start();
        }

        private void mapBox_MouseUp(object sender, MouseEventArgs e) {
            if (processID == 0)
                return;
            xMouse.Text = e.X.ToString();
            yMouse.Text = (mapHeight-e.Y).ToString();
        }
    }
}
