﻿namespace AerolineaFrba.Abm_Aeronave
{
    partial class IndiceAeronave
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
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
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.AltaButton = new System.Windows.Forms.Button();
            this.ModificacionButton = new System.Windows.Forms.Button();
            this.BajaButton = new System.Windows.Forms.Button();
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.SuspendLayout();
            // 
            // AltaButton
            // 
            this.AltaButton.Location = new System.Drawing.Point(47, 47);
            this.AltaButton.Name = "AltaButton";
            this.AltaButton.Size = new System.Drawing.Size(188, 55);
            this.AltaButton.TabIndex = 0;
            this.AltaButton.Text = "Alta de Aeronave";
            this.AltaButton.UseVisualStyleBackColor = true;
            this.AltaButton.Click += new System.EventHandler(this.altaButton_Click);
            // 
            // ModificacionButton
            // 
            this.ModificacionButton.Location = new System.Drawing.Point(47, 108);
            this.ModificacionButton.Name = "ModificacionButton";
            this.ModificacionButton.Size = new System.Drawing.Size(188, 59);
            this.ModificacionButton.TabIndex = 1;
            this.ModificacionButton.Text = "Modificar Aeronave";
            this.ModificacionButton.UseVisualStyleBackColor = true;
            this.ModificacionButton.Click += new System.EventHandler(this.ModificacionButton_Click);
            // 
            // BajaButton
            // 
            this.BajaButton.Location = new System.Drawing.Point(47, 173);
            this.BajaButton.Name = "BajaButton";
            this.BajaButton.Size = new System.Drawing.Size(188, 59);
            this.BajaButton.TabIndex = 2;
            this.BajaButton.Text = "Baja de Aeronave";
            this.BajaButton.UseVisualStyleBackColor = true;
            this.BajaButton.Click += new System.EventHandler(this.BajaButton_Click);
            // 
            // groupBox1
            // 
            this.groupBox1.Location = new System.Drawing.Point(26, 26);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Size = new System.Drawing.Size(225, 224);
            this.groupBox1.TabIndex = 3;
            this.groupBox1.TabStop = false;
            this.groupBox1.Text = "Opciones de Aeronave";
            // 
            // IndiceAeronave
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(284, 262);
            this.Controls.Add(this.BajaButton);
            this.Controls.Add(this.ModificacionButton);
            this.Controls.Add(this.AltaButton);
            this.Controls.Add(this.groupBox1);
            this.Name = "IndiceAeronave";
            this.Text = "ABM Aeronaves";
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.Button AltaButton;
        private System.Windows.Forms.Button ModificacionButton;
        private System.Windows.Forms.Button BajaButton;
        private System.Windows.Forms.GroupBox groupBox1;
    }
}