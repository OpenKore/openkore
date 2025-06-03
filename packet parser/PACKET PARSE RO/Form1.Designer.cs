namespace PACKET_PARSE_RO
{
    partial class Form1
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            components = new System.ComponentModel.Container();
            groupBox1 = new GroupBox();
            pacotesrec = new RichTextBox();
            iniciarcap = new Button();
            groupBox2 = new GroupBox();
            pacotesenv = new RichTextBox();
            ipserver = new TextBox();
            groupBox3 = new GroupBox();
            portserver = new TextBox();
            groupBox4 = new GroupBox();
            networklist = new ComboBox();
            groupBox5 = new GroupBox();
            groupBox6 = new GroupBox();
            lblTotalPackets = new Label();
            groupBox7 = new GroupBox();
            lblUniquePackets = new Label();
            groupBox8 = new GroupBox();
            lblVariablePackets = new Label();
            groupBox9 = new GroupBox();
            statusLabel = new Label();
            lblInterfaceInfo = new Label();
            packetListView = new ListView();
            timer1 = new System.Windows.Forms.Timer(components);
            groupBox1.SuspendLayout();
            groupBox2.SuspendLayout();
            groupBox3.SuspendLayout();
            groupBox4.SuspendLayout();
            groupBox5.SuspendLayout();
            groupBox6.SuspendLayout();
            groupBox7.SuspendLayout();
            groupBox8.SuspendLayout();
            groupBox9.SuspendLayout();
            SuspendLayout();
            // 
            // groupBox1
            // 
            groupBox1.Controls.Add(pacotesrec);
            groupBox1.Location = new Point(12, 220);
            groupBox1.Name = "groupBox1";
            groupBox1.Size = new Size(600, 720);
            groupBox1.TabIndex = 0;
            groupBox1.TabStop = false;
            groupBox1.Text = "Pacotes Recebidos";
            // 
            // pacotesrec
            // 
            pacotesrec.BackColor = Color.Black;
            pacotesrec.Dock = DockStyle.Fill;
            pacotesrec.ForeColor = Color.LightGray;
            pacotesrec.Location = new Point(3, 19);
            pacotesrec.Name = "pacotesrec";
            pacotesrec.Size = new Size(594, 698);
            pacotesrec.TabIndex = 0;
            pacotesrec.Text = "";
            // 
            // iniciarcap
            // 
            iniciarcap.BackColor = Color.DodgerBlue;
            iniciarcap.FlatStyle = FlatStyle.Flat;
            iniciarcap.Font = new Font("Segoe UI", 9F, FontStyle.Bold, GraphicsUnit.Point);
            iniciarcap.ForeColor = Color.White;
            iniciarcap.Location = new Point(12, 12);
            iniciarcap.Name = "iniciarcap";
            iniciarcap.Size = new Size(110, 35);
            iniciarcap.TabIndex = 0;
            iniciarcap.Text = "Iniciar Captura";
            iniciarcap.UseVisualStyleBackColor = false;
            iniciarcap.Click += iniciarcap_Click;
            // 
            // groupBox2
            // 
            groupBox2.Controls.Add(pacotesenv);
            groupBox2.Location = new Point(618, 220);
            groupBox2.Name = "groupBox2";
            groupBox2.Size = new Size(600, 720);
            groupBox2.TabIndex = 1;
            groupBox2.TabStop = false;
            groupBox2.Text = "Pacotes Enviados";
            // 
            // pacotesenv
            // 
            pacotesenv.BackColor = Color.Black;
            pacotesenv.Dock = DockStyle.Fill;
            pacotesenv.ForeColor = Color.LightGray;
            pacotesenv.Location = new Point(3, 19);
            pacotesenv.Name = "pacotesenv";
            pacotesenv.Size = new Size(594, 698);
            pacotesenv.TabIndex = 1;
            pacotesenv.Text = "";
            // 
            // ipserver
            // 
            ipserver.Location = new Point(6, 16);
            ipserver.Name = "ipserver";
            ipserver.Size = new Size(120, 23);
            ipserver.TabIndex = 2;
            ipserver.TextChanged += ipserver_TextChanged;
            // 
            // groupBox3
            // 
            groupBox3.Controls.Add(ipserver);
            groupBox3.Location = new Point(128, 8);
            groupBox3.Name = "groupBox3";
            groupBox3.Size = new Size(132, 45);
            groupBox3.TabIndex = 2;
            groupBox3.TabStop = false;
            groupBox3.Text = "IP Servidor";
            // 
            // portserver
            // 
            portserver.Location = new Point(6, 16);
            portserver.Name = "portserver";
            portserver.Size = new Size(60, 23);
            portserver.TabIndex = 2;
            portserver.TextChanged += portserver_TextChanged;
            // 
            // groupBox4
            // 
            groupBox4.Controls.Add(portserver);
            groupBox4.Location = new Point(266, 8);
            groupBox4.Name = "groupBox4";
            groupBox4.Size = new Size(72, 45);
            groupBox4.TabIndex = 3;
            groupBox4.TabStop = false;
            groupBox4.Text = "Porta";
            // 
            // networklist
            // 
            networklist.FormattingEnabled = true;
            networklist.Location = new Point(6, 16);
            networklist.Name = "networklist";
            networklist.Size = new Size(310, 23);
            networklist.TabIndex = 3;
            networklist.SelectedIndexChanged += networklist_SelectedIndexChanged;
            // 
            // groupBox5
            // 
            groupBox5.Controls.Add(networklist);
            groupBox5.Location = new Point(344, 8);
            groupBox5.Name = "groupBox5";
            groupBox5.Size = new Size(322, 45);
            groupBox5.TabIndex = 3;
            groupBox5.TabStop = false;
            groupBox5.Text = "Interface de Rede";
            // 
            // groupBox6
            // 
            groupBox6.Controls.Add(lblTotalPackets);
            groupBox6.Location = new Point(12, 59);
            groupBox6.Name = "groupBox6";
            groupBox6.Size = new Size(150, 50);
            groupBox6.TabIndex = 4;
            groupBox6.TabStop = false;
            groupBox6.Text = "Pacotes Processados";
            // 
            // lblTotalPackets
            // 
            lblTotalPackets.AutoSize = true;
            lblTotalPackets.Font = new Font("Segoe UI", 14F, FontStyle.Bold, GraphicsUnit.Point);
            lblTotalPackets.ForeColor = Color.DarkBlue;
            lblTotalPackets.Location = new Point(6, 19);
            lblTotalPackets.Name = "lblTotalPackets";
            lblTotalPackets.Size = new Size(23, 25);
            lblTotalPackets.TabIndex = 0;
            lblTotalPackets.Text = "0";
            // 
            // groupBox7
            // 
            groupBox7.Controls.Add(lblUniquePackets);
            groupBox7.Location = new Point(168, 59);
            groupBox7.Name = "groupBox7";
            groupBox7.Size = new Size(130, 50);
            groupBox7.TabIndex = 5;
            groupBox7.TabStop = false;
            groupBox7.Text = "Pacotes Únicos";
            // 
            // lblUniquePackets
            // 
            lblUniquePackets.AutoSize = true;
            lblUniquePackets.Font = new Font("Segoe UI", 14F, FontStyle.Bold, GraphicsUnit.Point);
            lblUniquePackets.ForeColor = Color.DarkGreen;
            lblUniquePackets.Location = new Point(6, 19);
            lblUniquePackets.Name = "lblUniquePackets";
            lblUniquePackets.Size = new Size(23, 25);
            lblUniquePackets.TabIndex = 1;
            lblUniquePackets.Text = "0";
            // 
            // groupBox8
            // 
            groupBox8.Controls.Add(lblVariablePackets);
            groupBox8.Location = new Point(304, 59);
            groupBox8.Name = "groupBox8";
            groupBox8.Size = new Size(130, 50);
            groupBox8.TabIndex = 5;
            groupBox8.TabStop = false;
            groupBox8.Text = "Pacotes Variáveis";
            // 
            // lblVariablePackets
            // 
            lblVariablePackets.AutoSize = true;
            lblVariablePackets.Font = new Font("Segoe UI", 14F, FontStyle.Bold, GraphicsUnit.Point);
            lblVariablePackets.ForeColor = Color.DarkOrange;
            lblVariablePackets.Location = new Point(8, 19);
            lblVariablePackets.Name = "lblVariablePackets";
            lblVariablePackets.Size = new Size(23, 25);
            lblVariablePackets.TabIndex = 2;
            lblVariablePackets.Text = "0";
            // 
            // groupBox9
            // 
            groupBox9.Controls.Add(statusLabel);
            groupBox9.Location = new Point(440, 59);
            groupBox9.Name = "groupBox9";
            groupBox9.Size = new Size(226, 50);
            groupBox9.TabIndex = 5;
            groupBox9.TabStop = false;
            groupBox9.Text = "Status";
            // 
            // statusLabel
            // 
            statusLabel.AutoSize = true;
            statusLabel.Font = new Font("Segoe UI", 10F, FontStyle.Bold, GraphicsUnit.Point);
            statusLabel.ForeColor = Color.DarkRed;
            statusLabel.Location = new Point(6, 19);
            statusLabel.Name = "statusLabel";
            statusLabel.Size = new Size(54, 19);
            statusLabel.TabIndex = 3;
            statusLabel.Text = "Parado";
            // 
            // lblInterfaceInfo
            // 
            lblInterfaceInfo.AutoSize = true;
            lblInterfaceInfo.Font = new Font("Segoe UI", 8F, FontStyle.Regular, GraphicsUnit.Point);
            lblInterfaceInfo.ForeColor = Color.DarkGray;
            lblInterfaceInfo.Location = new Point(672, 20);
            lblInterfaceInfo.Name = "lblInterfaceInfo";
            lblInterfaceInfo.Size = new Size(0, 13);
            lblInterfaceInfo.TabIndex = 6;
            // 
            // packetListView
            // 
            packetListView.FullRowSelect = true;
            packetListView.GridLines = true;
            packetListView.Location = new Point(12, 115);
            packetListView.Name = "packetListView";
            packetListView.Size = new Size(1206, 100);
            packetListView.TabIndex = 8;
            packetListView.UseCompatibleStateImageBehavior = false;
            packetListView.View = View.Details;
            packetListView.Columns.Add("Opcode", 100);
            packetListView.Columns.Add("Tamanho", 100);
            packetListView.Columns.Add("Tipo", 120);
            packetListView.Columns.Add("Ocorrências", 120);
            packetListView.Font = new Font("Consolas", 9F, FontStyle.Regular, GraphicsUnit.Point);
            // 
            // Form1
            // 
            AutoScaleDimensions = new SizeF(7F, 15F);
            AutoScaleMode = AutoScaleMode.Font;
            AutoSize = true;
            ClientSize = new Size(1230, 950);
            Controls.Add(groupBox8);
            Controls.Add(packetListView);
            Controls.Add(lblInterfaceInfo);
            Controls.Add(groupBox9);
            Controls.Add(groupBox7);
            Controls.Add(groupBox6);
            Controls.Add(groupBox5);
            Controls.Add(groupBox4);
            Controls.Add(groupBox3);
            Controls.Add(groupBox2);
            Controls.Add(iniciarcap);
            Controls.Add(groupBox1);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            Name = "Form1";
            StartPosition = FormStartPosition.CenterScreen;
            Text = "ROla Sniff - Packet Monitor";
            groupBox1.ResumeLayout(false);
            groupBox2.ResumeLayout(false);
            groupBox3.ResumeLayout(false);
            groupBox3.PerformLayout();
            groupBox4.ResumeLayout(false);
            groupBox4.PerformLayout();
            groupBox5.ResumeLayout(false);
            groupBox6.ResumeLayout(false);
            groupBox6.PerformLayout();
            groupBox7.ResumeLayout(false);
            groupBox7.PerformLayout();
            groupBox8.ResumeLayout(false);
            groupBox8.PerformLayout();
            groupBox9.ResumeLayout(false);
            groupBox9.PerformLayout();
            ResumeLayout(false);
            PerformLayout();
        }

        #endregion

        private GroupBox groupBox1;
        private Button iniciarcap;
        private GroupBox groupBox2;
        private TextBox ipserver;
        private GroupBox groupBox3;
        private TextBox portserver;
        private GroupBox groupBox4;
        private ComboBox networklist;
        private GroupBox groupBox5;
        private RichTextBox pacotesrec;
        private RichTextBox pacotesenv;
        private GroupBox groupBox6;
        private GroupBox groupBox7;
        private GroupBox groupBox8;
        private GroupBox groupBox9;
        private Label lblTotalPackets;
        private Label lblUniquePackets;
        private Label lblVariablePackets;
        private Label statusLabel;
        private Label lblInterfaceInfo;
        private ListView packetListView;
        private System.Windows.Forms.Timer timer1;
    }
}