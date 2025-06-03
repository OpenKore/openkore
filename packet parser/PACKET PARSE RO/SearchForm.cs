using System;
using System.Drawing;
using System.Windows.Forms;

namespace PACKET_PARSE_RO
{
    public class SearchForm : Form
    {
        private TextBox txtSearch;
        private CheckBox chkMatchCase;
        private CheckBox chkSearchHex;
        private RadioButton rbDown;
        private RadioButton rbUp;
        private Label lblOccurrences;
        private ComboBox cmbSearchArea;

        public event EventHandler SearchNext;

        public string SearchText => txtSearch.Text;
        public bool MatchCase => chkMatchCase.Checked;
        public bool SearchUp => rbUp.Checked;
        public bool SearchHex => chkSearchHex.Checked;

        public int SearchArea
        {
            get => cmbSearchArea.SelectedIndex;
            set => cmbSearchArea.SelectedIndex = value;
        }

        public SearchForm()
        {
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.StartPosition = FormStartPosition.CenterParent;
            this.Text = "Buscar";
            this.Size = new Size(460, 260); 

            CreateControls();
        }

        private void CreateControls()
        {
            Label lblSearch = new Label
            {
                Text = "Buscar por:",
                Location = new Point(10, 15),
                AutoSize = true
            };
            this.Controls.Add(lblSearch);

            txtSearch = new TextBox
            {
                Location = new Point(10, 35),
                Size = new Size(420, 22)
            };
            this.Controls.Add(txtSearch);

            Label lblSearchArea = new Label
            {
                Text = "Buscar em:",
                Location = new Point(10, 65),
                AutoSize = true
            };
            this.Controls.Add(lblSearchArea);

            cmbSearchArea = new ComboBox
            {
                Location = new Point(10, 85),
                Size = new Size(200, 22),
                DropDownStyle = ComboBoxStyle.DropDownList
            };
            cmbSearchArea.Items.AddRange(new object[] { "Pacotes Recebidos", "Pacotes Enviados" });
            cmbSearchArea.SelectedIndex = 0;
            this.Controls.Add(cmbSearchArea);

            chkMatchCase = new CheckBox
            {
                Text = "Diferenciar maiúsculas/minúsculas",
                Location = new Point(10, 115),
                AutoSize = true
            };
            this.Controls.Add(chkMatchCase);

            chkSearchHex = new CheckBox
            {
                Text = "Buscar valor hexadecimal",
                Location = new Point(10, 140),
                AutoSize = true
            };
            this.Controls.Add(chkSearchHex);

            rbDown = new RadioButton
            {
                Text = "Para baixo",
                Location = new Point(280, 115),
                AutoSize = true,
                Checked = true
            };
            this.Controls.Add(rbDown);

            rbUp = new RadioButton
            {
                Text = "Para cima",
                Location = new Point(280, 140),
                AutoSize = true
            };
            this.Controls.Add(rbUp);

            lblOccurrences = new Label
            {
                Text = "Ocorrências: 0",
                Location = new Point(10, 170),
                AutoSize = true,
                ForeColor = Color.Blue
            };
            this.Controls.Add(lblOccurrences);

            Button btnFindNext = new Button
            {
                Text = "Buscar Próximo",
                Location = new Point(230, 170),
                Size = new Size(100, 28)
            };
            btnFindNext.Click += BtnFindNext_Click;
            this.Controls.Add(btnFindNext);

            Button btnClose = new Button
            {
                Text = "Fechar",
                Location = new Point(335, 170),
                Size = new Size(100, 28)
            };
            btnClose.Click += BtnClose_Click;
            this.Controls.Add(btnClose);

            this.AcceptButton = btnFindNext;
            this.CancelButton = btnClose;
        }

        private void BtnFindNext_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(txtSearch.Text))
            {
                MessageBox.Show("Por favor, digite um texto para buscar.", "Busca",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            SearchNext?.Invoke(this, EventArgs.Empty);
        }

        private void BtnClose_Click(object sender, EventArgs e)
        {
            this.DialogResult = DialogResult.Cancel;
            this.Close();
        }

        public void UpdateOccurrencesCount(int count)
        {
            lblOccurrences.Text = $"Ocorrências: {count}";
        }
    }
}