import os
from fpdf import FPDF

class PDFGenerator:
    def generate_pdf(self, user_data):
        """
        Generates a PDF document based on the provided user data.
        
        Args:
        user_data (dict): A dictionary containing user data with keys 'name', 'email', and 'hours_worked'.
        
        Returns:
        str: The file path of the generated PDF.
        """
        pdf = FPDF()
        pdf.add_page()
        pdf.set_font("Arial", size=12)
        
        # Adding a cell
        pdf.cell(200, 10, txt=f"Name: {user_data['name']}", ln=True)
        pdf.cell(200, 10, txt=f"Email: {user_data['email']}", ln=True)
        pdf.cell(200, 10, txt=f"Hours Worked: {user_data['hours_worked']}", ln=True)

        # Save the pdf with name .pdf
        output_path = os.path.join(os.getcwd(), f"{user_data['name']}_{user_data['email']}.pdf")
        pdf.output(output_path)
        
        return output_path
