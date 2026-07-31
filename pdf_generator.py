import jinja2
from fpdf import FPDF

class PDFGenerator:
    def generate_pdf(self, data):
        """
        Generates a PDF document using the provided data.
        
        Args:
            data (dict): Data to be included in the PDF.
            
        Returns:
            bytes: Bytes object containing the PDF content.
        """
        template_loader = jinja2.FileSystemLoader(searchpath="./")
        template_env = jinja2.Environment(loader=template_loader)
        template = template_env.get_template("template.html")

        # Render the data into HTML
        html_content = template.render(data=data)

        # Convert HTML to PDF
        pdf = FPDF()
        pdf.add_page()
        pdf.set_font("Arial", size=12)
        pdf.multi_cell(0, 10, txt=html_content, align='L')
        return pdf.output(dest='S').encode('latin-1')

# Example usage:
if __name__ == "__main__":
    data_service = DataService()
    endpoint = "https://api.example.com/data"
    data = data_service.fetch_data(endpoint)
    
    if data:
        pdf_generator = PDFGenerator()
        pdf_content = pdf_generator.generate_pdf(data)
        
        with open("output.pdf", "wb") as file:
            file.write(pdf_content)
