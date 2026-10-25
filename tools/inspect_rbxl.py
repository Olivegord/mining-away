import struct, json, pathlib

def u32(b,o=0): return struct.unpack_from('<I',b,o)[0]
def string(b,o):
    n=u32(b,o); o+=4
    return b[o:o+n].decode('utf8','replace'),o+n

def lz4(data,size):
    out=bytearray();i=0
    while i<len(data):
        tok=data[i];i+=1;n=tok>>4
        if n==15:
            while True:
                x=data[i];i+=1;n+=x
                if x<255:break
        out.extend(data[i:i+n]);i+=n
        if i>=len(data):break
        off=data[i]|data[i+1]<<8;i+=2;n=tok&15
        if n==15:
            while True:
                x=data[i];i+=1;n+=x
                if x<255:break
        n+=4
        for j in range(n):out.append(out[-off])
    assert len(out)==size,(len(out),size)
    return bytes(out)

def inspect(path):
    b=path.read_bytes();i=32;classes={};props={};meta=[]
    while i<len(b):
        kind=b[i:i+4];cl,ul,_=struct.unpack_from('<III',b,i+4);i+=16
        d=lz4(b[i:i+cl],ul) if cl else b[i:i+ul];i+=cl or ul
        if kind==b'INST':
            cid=u32(d);name,p=string(d,4);fmt=d[p];count=u32(d,p+1)
            classes[cid]={'class':name,'count':count};props[cid]={}
        elif kind==b'PROP':
            cid=u32(d);name,p=string(d,4);typ=d[p];p+=1
            if typ==1:
                vs=[]
                try:
                    while p<len(d):s,p=string(d,p);vs.append(s)
                    props[cid][name]=vs
                except Exception as ex:props[cid][name]={'error':str(ex)}
        elif kind==b'META':meta.append(d.decode('utf8','replace'))
    return {'file':str(path),'meta':meta,'classes':classes,'props':props}

if __name__=='__main__':
    for p in map(pathlib.Path,__import__('sys').argv[1:]):
        result=inspect(p)
        out=pathlib.Path('/private/tmp/mining-away-inspection')/(p.stem+'.json');out.write_text(json.dumps(result,indent=2))
        print(str(p))
        for cid,c in result['classes'].items():
            if c['class'] in ['Script','ModuleScript','LocalScript']:
                print(cid,c,result['props'][cid])
