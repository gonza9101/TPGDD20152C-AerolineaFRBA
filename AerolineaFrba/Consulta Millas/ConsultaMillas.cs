﻿using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using AerolineaFrba.Helpers;
using AerolineaFrba.DAO;
using AerolineaFrba.DTO;

namespace AerolineaFrba.Consulta_Millas
{
    public partial class ConsultaMillas : Form
    {
        public ConsultaMillas()
        {
            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            if (validar()) return;
            List<MillasDTO> listadoMillas = MillasDAO.getListadoMillas(this.textDNI.Text);
            listadoMillas = (from m in listadoMillas
                          orderby m.Fecha
                          select m).ToList();
            dataGridView1.DataSource = listadoMillas;
            this.textBox2.Text = MillasDAO.getMillas(this.textDNI.Text);
            UpdateDataGridViewRowColors();
        }

        private bool validar()
        {
            errorProvider1.Clear();
            bool ret = false;
            if ((!Utility.esDNI(this.textDNI) && !(this.textDNI.Text == "")) || (this.textDNI.Text == ""))
            {
                errorProvider1.SetError(this.textDNI, "Debe ingresar un DNI (no puede superar los 8 digitos).");
                ret = true;
            }
            return ret;
        }

        private void UpdateDataGridViewRowColors()
        {
            foreach (DataGridViewRow row in dataGridView1.Rows)
            {
                int RowType = Convert.ToInt32(row.Cells[0].Value);

                if (RowType == 2)
                {
                    row.DefaultCellStyle.BackColor = Color.Red;
                    row.DefaultCellStyle.ForeColor = Color.White;
                }
                else if (RowType == 1)
                {
                    row.DefaultCellStyle.BackColor = Color.Green;
                    row.DefaultCellStyle.ForeColor = Color.Black;
                }

            }
            dataGridView1.Columns[0].Visible = false;
        }

        private void button2_Click(object sender, EventArgs e)
        {
            this.errorProvider1.Clear();
            dataGridView1.DataSource = null;
            dataGridView1.DefaultCellStyle.BackColor = Color.White;
            dataGridView1.DefaultCellStyle.ForeColor = Color.Black;
            this.textBox2.Text = "";
            this.textDNI.Text = "";
        }

    }
}
