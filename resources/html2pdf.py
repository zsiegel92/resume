import pdfkit

css = 'style.css'
options={
	"margin-top":"0in",
	"margin-bottom": "0in",
	"margin-left": "0in",
	"margin-right":"0in",
	"page-height":"11in",
	"page-width":"9in",
	"encoding":"UTF-8",
	"print-media-type":"",
	"no-stop-slow-scripts":""
}
# pdfkit.from_file('index.html','index.pdf',options=options,css=css)
pdfkit.from_file('index.html','index.pdf',options=options)
# wkhtmltopdf --margin-bottom 0 --margin-top 0 --margin-left 0 --margin-right 0 --page-height 27.94 --page-width 24.13 --encoding UTF-8 --allow . --enable-plugins --no-print-media-type  index.html index.pdf
