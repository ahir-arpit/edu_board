import io
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter

router = APIRouter(prefix="/export", tags=["export"])

class ExportPDFRequest(BaseModel):
    title: Optional[str] = "SmartBoard Notes"
    # List of pages, where each page contains a list of strokes/shapes
    pages: List[List[Dict[str, Any]]]

def parse_color(color_str: str):
    """
    Parses colors like "0xFF2196F3", "#2196F3", or "rgba(x,y,z,a)" and
    returns (r, g, b, alpha) values in [0..1].
    """
    if not color_str:
        return 0, 0, 0, 1.0
        
    try:
        color_str = color_str.strip()
        if color_str.startswith("0xFF") or color_str.startswith("0xff"):
            # Format: 0xAARRGGBB
            hex_val = color_str[4:]
            r = int(hex_val[0:2], 16) / 255.0
            g = int(hex_val[2:4], 16) / 255.0
            b = int(hex_val[4:6], 16) / 255.0
            return r, g, b, 1.0
        elif color_str.startswith("#"):
            # Format: #RRGGBB or #RRGGBBAA
            hex_val = color_str[1:]
            r = int(hex_val[0:2], 16) / 255.0
            g = int(hex_val[2:4], 16) / 255.0
            b = int(hex_val[4:6], 16) / 255.0
            a = 1.0
            if len(hex_val) == 8:
                a = int(hex_val[6:8], 16) / 255.0
            return r, g, b, a
        elif color_str.startswith("0x") and len(color_str) >= 8:
            # Check length: could be 0xRRGGBB (length 8) or 0xAARRGGBB (length 10)
            hex_val = color_str[2:]
            if len(hex_val) == 8:
                a = int(hex_val[0:2], 16) / 255.0
                r = int(hex_val[2:4], 16) / 255.0
                g = int(hex_val[4:6], 16) / 255.0
                b = int(hex_val[6:8], 16) / 255.0
            else:
                r = int(hex_val[0:2], 16) / 255.0
                g = int(hex_val[2:4], 16) / 255.0
                b = int(hex_val[4:6], 16) / 255.0
                a = 1.0
            return r, g, b, a
    except Exception:
        pass
    return 0, 0, 0, 1.0

@router.post("/pdf")
def export_pdf(request: ExportPDFRequest):
    """
    Renders vector strokes and shapes onto a PDF and streams it to the user.
    """
    try:
        pdf_buffer = io.BytesIO()
        # Create a standard letter-sized PDF canvas (612 x 792 pt)
        page_w, page_h = letter
        pdf = canvas.Canvas(pdf_buffer, pagesize=letter)
        
        # Scale factor if user canvas is larger/smaller than letter size
        # Assuming mobile canvas coordinate system around 375x812 or similar, 
        # we will render points directly or scale them.
        
        for i, page_items in enumerate(request.pages):
            if i > 0:
                pdf.showPage()
                
            # Draw header
            pdf.setFont("Helvetica-Bold", 10)
            pdf.setFillColorRGB(0.5, 0.5, 0.5)
            pdf.drawString(36, page_h - 36, f"{request.title} - Page {i + 1}")
            
            for item in page_items:
                item_type = item.get("type", "stroke")
                color_str = item.get("color", "0xFF000000")
                r, g, b, a = parse_color(color_str)
                width = item.get("width", item.get("stroke_width", 2.0))
                
                pdf.setStrokeColorRGB(r, g, b)
                pdf.setLineWidth(width)
                
                if item_type == "stroke":
                    points = item.get("points", [])
                    if len(points) < 2:
                        continue
                        
                    path = pdf.beginPath()
                    # Flutter (0,0) is top-left, ReportLab (0,0) is bottom-left
                    # So we invert y coordinates: page_h - y
                    start_pt = points[0]
                    path.moveTo(start_pt.get("x", 0.0), page_h - start_pt.get("y", 0.0))
                    
                    for pt in points[1:]:
                        path.lineTo(pt.get("x", 0.0), page_h - pt.get("y", 0.0))
                    pdf.drawPath(path, fill=0, stroke=1)
                    
                elif item_type == "shape":
                    shape_type = item.get("shape_type", "line")
                    start_x = item.get("start_x", 0.0)
                    start_y = page_h - item.get("start_y", 0.0)
                    end_x = item.get("end_x", 0.0)
                    end_y = page_h - item.get("end_y", 0.0)
                    
                    # Fill settings (if fill is specified)
                    fill_color_str = item.get("fill_color")
                    has_fill = fill_color_str is not None
                    
                    if shape_type == "line":
                        pdf.line(start_x, start_y, end_x, end_y)
                    elif shape_type == "arrow":
                        # Draw shaft
                        pdf.line(start_x, start_y, end_x, end_y)
                        # Draw a basic arrowhead at end
                        import math
                        angle = math.atan2(end_y - start_y, end_x - start_x)
                        arrow_len = 10.0
                        arrow_angle = math.pi / 6 # 30 deg
                        
                        pt1_x = end_x - arrow_len * math.cos(angle - arrow_angle)
                        pt1_y = end_y - arrow_len * math.sin(angle - arrow_angle)
                        pt2_x = end_x - arrow_len * math.cos(angle + arrow_angle)
                        pt2_y = end_y - arrow_len * math.sin(angle + arrow_angle)
                        
                        pdf.line(end_x, end_y, pt1_x, pt1_y)
                        pdf.line(end_x, end_y, pt2_x, pt2_y)
                    elif shape_type == "rectangle":
                        x = min(start_x, end_x)
                        y = min(start_y, end_y)
                        w = abs(end_x - start_x)
                        h = abs(end_y - start_y)
                        
                        if has_fill:
                            fr, fg, fb, fa = parse_color(fill_color_str)
                            pdf.setFillColorRGB(fr, fg, fb)
                            pdf.rect(x, y, w, h, fill=1, stroke=1)
                        else:
                            pdf.rect(x, y, w, h, fill=0, stroke=1)
                    elif shape_type == "circle":
                        dx = end_x - start_x
                        dy = end_y - start_y
                        radius = (dx**2 + dy**2) ** 0.5
                        
                        if has_fill:
                            fr, fg, fb, fa = parse_color(fill_color_str)
                            pdf.setFillColorRGB(fr, fg, fb)
                            pdf.circle(start_x, start_y, radius, fill=1, stroke=1)
                        else:
                            pdf.circle(start_x, start_y, radius, fill=0, stroke=1)
                    elif shape_type == "triangle":
                        # Draw triangle from bounds (start_x, start_y) to (end_x, end_y)
                        mid_x = (start_x + end_x) / 2.0
                        
                        p = pdf.beginPath()
                        p.moveTo(mid_x, end_y) # Apex
                        p.lineTo(start_x, start_y) # Bottom left
                        p.lineTo(end_x, start_y) # Bottom right
                        p.close()
                        
                        if has_fill:
                            fr, fg, fb, fa = parse_color(fill_color_str)
                            pdf.setFillColorRGB(fr, fg, fb)
                            pdf.drawPath(p, fill=1, stroke=1)
                        else:
                            pdf.drawPath(p, fill=0, stroke=1)
                            
        pdf.save()
        pdf_buffer.seek(0)
        
        headers = {
            'Content-Disposition': 'attachment; filename="smartboard_notes.pdf"'
        }
        return StreamingResponse(pdf_buffer, media_type="application/pdf", headers=headers)
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate PDF: {str(e)}"
        )
