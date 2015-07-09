namespace mapView {
    partial class Form1 {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing) {
            if (disposing && (components != null)) {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent() {
            this.components = new System.ComponentModel.Container();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Form1));
            this.processGroup = new System.Windows.Forms.GroupBox();
            this.button1 = new System.Windows.Forms.Button();
            this.label1 = new System.Windows.Forms.Label();
            this.processListBox = new System.Windows.Forms.ComboBox();
            this.updateTimer = new System.Windows.Forms.Timer(this.components);
            this.mapBox = new System.Windows.Forms.PictureBox();
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.yMouse = new System.Windows.Forms.Label();
            this.xMouse = new System.Windows.Forms.Label();
            this.label3 = new System.Windows.Forms.Label();
            this.label2 = new System.Windows.Forms.Label();
            this.mapStr = new System.Windows.Forms.Label();
            this.yStr = new System.Windows.Forms.Label();
            this.xStr = new System.Windows.Forms.Label();
            this.processGroup.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.mapBox)).BeginInit();
            this.groupBox1.SuspendLayout();
            this.SuspendLayout();
            // 
            // processGroup
            // 
            this.processGroup.Controls.Add(this.button1);
            this.processGroup.Controls.Add(this.label1);
            this.processGroup.Controls.Add(this.processListBox);
            this.processGroup.Location = new System.Drawing.Point(3, 0);
            this.processGroup.Name = "processGroup";
            this.processGroup.Size = new System.Drawing.Size(315, 54);
            this.processGroup.TabIndex = 0;
            this.processGroup.TabStop = false;
            // 
            // button1
            // 
            this.button1.Location = new System.Drawing.Point(238, 28);
            this.button1.Name = "button1";
            this.button1.Size = new System.Drawing.Size(71, 19);
            this.button1.TabIndex = 3;
            this.button1.Text = "重新整理";
            this.button1.UseVisualStyleBackColor = true;
            this.button1.Click += new System.EventHandler(this.button1_Click);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(6, 12);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(68, 12);
            this.label1.TabIndex = 2;
            this.label1.Text = "請選擇人物:";
            // 
            // processListBox
            // 
            this.processListBox.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.processListBox.FormattingEnabled = true;
            this.processListBox.Location = new System.Drawing.Point(6, 27);
            this.processListBox.Name = "processListBox";
            this.processListBox.Size = new System.Drawing.Size(226, 20);
            this.processListBox.TabIndex = 1;
            this.processListBox.SelectedIndexChanged += new System.EventHandler(this.processListBox_SelectedIndexChanged);
            // 
            // updateTimer
            // 
            this.updateTimer.Interval = 3000;
            this.updateTimer.Tick += new System.EventHandler(this.updateTimer_Tick);
            // 
            // mapBox
            // 
            this.mapBox.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.mapBox.InitialImage = null;
            this.mapBox.Location = new System.Drawing.Point(3, 120);
            this.mapBox.Name = "mapBox";
            this.mapBox.Size = new System.Drawing.Size(315, 277);
            this.mapBox.TabIndex = 1;
            this.mapBox.TabStop = false;
            this.mapBox.MouseUp += new System.Windows.Forms.MouseEventHandler(this.mapBox_MouseUp);
            // 
            // groupBox1
            // 
            this.groupBox1.Controls.Add(this.yMouse);
            this.groupBox1.Controls.Add(this.xMouse);
            this.groupBox1.Controls.Add(this.label3);
            this.groupBox1.Controls.Add(this.label2);
            this.groupBox1.Controls.Add(this.mapStr);
            this.groupBox1.Controls.Add(this.yStr);
            this.groupBox1.Controls.Add(this.xStr);
            this.groupBox1.Location = new System.Drawing.Point(3, 60);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Size = new System.Drawing.Size(315, 54);
            this.groupBox1.TabIndex = 2;
            this.groupBox1.TabStop = false;
            // 
            // yMouse
            // 
            this.yMouse.AutoSize = true;
            this.yMouse.Location = new System.Drawing.Point(108, 33);
            this.yMouse.Name = "yMouse";
            this.yMouse.Size = new System.Drawing.Size(19, 12);
            this.yMouse.TabIndex = 12;
            this.yMouse.Text = "Y: ";
            // 
            // xMouse
            // 
            this.xMouse.AutoSize = true;
            this.xMouse.Location = new System.Drawing.Point(65, 33);
            this.xMouse.Name = "xMouse";
            this.xMouse.Size = new System.Drawing.Size(19, 12);
            this.xMouse.TabIndex = 11;
            this.xMouse.Text = "X: ";
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Font = new System.Drawing.Font("PMingLiU", 9F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(136)));
            this.label3.Location = new System.Drawing.Point(6, 33);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(57, 12);
            this.label3.TabIndex = 10;
            this.label3.Text = "滑鼠位置";
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Font = new System.Drawing.Font("PMingLiU", 9F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(136)));
            this.label2.Location = new System.Drawing.Point(6, 16);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(57, 12);
            this.label2.TabIndex = 9;
            this.label2.Text = "當前位置";
            // 
            // mapStr
            // 
            this.mapStr.AutoSize = true;
            this.mapStr.Location = new System.Drawing.Point(65, 16);
            this.mapStr.Name = "mapStr";
            this.mapStr.Size = new System.Drawing.Size(32, 12);
            this.mapStr.TabIndex = 8;
            this.mapStr.Text = "Map: ";
            // 
            // yStr
            // 
            this.yStr.AutoSize = true;
            this.yStr.Location = new System.Drawing.Point(215, 16);
            this.yStr.Name = "yStr";
            this.yStr.Size = new System.Drawing.Size(19, 12);
            this.yStr.TabIndex = 7;
            this.yStr.Text = "Y: ";
            // 
            // xStr
            // 
            this.xStr.AutoSize = true;
            this.xStr.Location = new System.Drawing.Point(172, 16);
            this.xStr.Name = "xStr";
            this.xStr.Size = new System.Drawing.Size(19, 12);
            this.xStr.TabIndex = 6;
            this.xStr.Text = "X: ";
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(324, 402);
            this.Controls.Add(this.groupBox1);
            this.Controls.Add(this.mapBox);
            this.Controls.Add(this.processGroup);
            this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedSingle;
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.MaximizeBox = false;
            this.MaximumSize = new System.Drawing.Size(800, 800);
            this.MinimumSize = new System.Drawing.Size(330, 427);
            this.Name = "Form1";
            this.Padding = new System.Windows.Forms.Padding(1);
            this.Text = "OpenKore 地圖顯示器";
            this.Shown += new System.EventHandler(this.Form1_Shown);
            this.Resize += new System.EventHandler(this.Form1_Resize);
            this.processGroup.ResumeLayout(false);
            this.processGroup.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.mapBox)).EndInit();
            this.groupBox1.ResumeLayout(false);
            this.groupBox1.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.GroupBox processGroup;
        private System.Windows.Forms.Button button1;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.ComboBox processListBox;
        private System.Windows.Forms.Timer updateTimer;
        private System.Windows.Forms.PictureBox mapBox;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.Label yStr;
        private System.Windows.Forms.Label xStr;
        private System.Windows.Forms.Label mapStr;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Label yMouse;
        private System.Windows.Forms.Label xMouse;
    }
}

