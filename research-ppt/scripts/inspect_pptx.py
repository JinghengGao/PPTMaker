"""Read-only OOXML audit. Uses only Python standard library; no PPT rewriting."""
import argparse, collections, json, pathlib, posixpath, re, zipfile
import xml.etree.ElementTree as ET

NS = {'p':'http://schemas.openxmlformats.org/presentationml/2006/main',
      'a':'http://schemas.openxmlformats.org/drawingml/2006/main',
      'r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}

def inspect(source):
    with zipfile.ZipFile(source) as z:
        pres = ET.fromstring(z.read('ppt/presentation.xml'))
        pages = sorted((n for n in z.namelist() if re.fullmatch(r'ppt/slides/slide\d+\.xml',n)),key=lambda n:int(re.search(r'(\d+)\.xml',n)[1]))
        themes = {}
        for name in z.namelist():
            if re.fullmatch(r'ppt/theme/theme\d+\.xml',name):
                root=ET.fromstring(z.read(name))
                themes[name]={'name':root.get('name'),'fonts':[e.attrib for e in root.iter() if e.tag.split('}')[-1] in ('latin','ea','cs')], 'colors':[{'role':e.tag.split('}')[-1],'values':[c.attrib for c in e]} for e in root.findall('.//a:clrScheme/*',NS)]}
        fonts, sizes, colors, all_fonts = collections.Counter(),collections.Counter(),collections.Counter(),collections.Counter()
        records=[]
        for i,name in enumerate(pages,1):
            root=ET.fromstring(z.read(name)); objects=[]
            for e in root.iter():
                if e.tag.split('}')[-1] in ('latin','ea','cs') and e.get('typeface'):all_fonts[e.get('typeface')]+=1
            relfile=posixpath.join(posixpath.dirname(name),'_rels',posixpath.basename(name)+'.rels')
            rels={e.get('Id'):{'type':e.get('Type').split('/')[-1],'target':e.get('Target')} for e in ET.fromstring(z.read(relfile))} if relfile in z.namelist() else {}
            for el in root.findall('.//p:spTree//*',NS):
                kind=el.tag.split('}')[-1]
                if kind not in ('sp','pic','graphicFrame','cxnSp'):continue
                nv=el.find('.//p:cNvPr',NS)
                xfrm=el.find('p:spPr/a:xfrm',NS)
                if xfrm is None:xfrm=el.find('p:xfrm',NS)
                geom={}
                if xfrm is not None:
                    for c in xfrm: geom[c.tag.split('}')[-1]]={k:round(int(v)/12700,3) if v.lstrip('-').isdigit() else v for k,v in c.attrib.items()}
                runs=[]
                for r in el.findall('.//a:r',NS):
                    rp=r.find('a:rPr',NS); t=r.find('a:t',NS)
                    item={'text':t.text if t is not None else '', 'properties':rp.attrib if rp is not None else {},'font':{},'color':[]}
                    if rp is not None:
                        for c in rp:
                            ck=c.tag.split('}')[-1]
                            if ck in ('latin','ea','cs'):item['font'][ck]=c.get('typeface');fonts[c.get('typeface')]+=1
                            if ck=='solidFill': item['color']=[{'type':e.tag.split('}')[-1],**e.attrib} for e in c]
                        if rp.get('sz'):sizes[int(rp.get('sz'))/100]+=1
                    runs.append(item)
                fill=el.find('p:spPr/a:solidFill',NS)
                line=el.find('p:spPr/a:ln',NS)
                for c in el.findall('.//a:srgbClr',NS):colors[c.get('val')]+=1
                blip=el.find('.//a:blip',NS)
                objects.append({'kind':kind,'name':nv.get('name') if nv is not None else '', 'geometry_pt':geom,'text':'\n'.join(e.text or '' for e in el.findall('.//a:t',NS)), 'runs':runs,'fill':ET.tostring(fill,encoding='unicode') if fill is not None else None,'line':ET.tostring(line,encoding='unicode') if line is not None else None,'media':rels.get(blip.get('{'+NS['r']+'}embed')) if blip is not None else None,'table':el.find('.//a:tbl',NS) is not None})
            bg = root.find('.//p:bg',NS)
            bg_blip = bg.find('.//a:blip',NS) if bg is not None else None
            records.append({'page':i,'slide_file':name,'relations':rels,'background':ET.tostring(bg,encoding='unicode') if bg is not None else None,'background_media':rels.get(bg_blip.get('{'+NS['r']+'}embed')) if bg_blip is not None else None,'objects':objects})
        return {'source':str(source),'canvas_emu':pres.find('p:sldSz',NS).attrib,'slide_count':len(records),'master_count':len([n for n in z.namelist() if re.fullmatch(r'ppt/slideMasters/slideMaster\d+\.xml',n)]),'layout_count':len([n for n in z.namelist() if re.fullmatch(r'ppt/slideLayouts/slideLayout\d+\.xml',n)]),'themes':themes,'all_font_declarations':dict(all_fonts),'explicit_font_counts':dict(fonts),'explicit_size_counts_pt':dict(sizes),'explicit_color_counts':dict(colors),'pages':records}

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('source');ap.add_argument('output');args=ap.parse_args()
    data=inspect(pathlib.Path(args.source));pathlib.Path(args.output).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:data[k] for k in ['slide_count','canvas_emu','master_count','layout_count','explicit_font_counts','explicit_size_counts_pt','explicit_color_counts']},ensure_ascii=False))
