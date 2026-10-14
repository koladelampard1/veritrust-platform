'use client';
import {useEffect,useRef,useState} from 'react';
import './consumer.css';

type State='matched_record'|'caution'|'do_not_use'|'unverifiable'|'service_unavailable';
type Result={state:State;lot_code?:string;message:string;product_name?:string;manufacturer_name?:string;expires_on?:string};
const presets:{label:string;state:State;lot_code?:string;message:string}[]=[
 {label:'Enrolled record',state:'matched_record',lot_code:'DEMO-LOT-1001',message:'A synthetic digital identifier matched an enrolled demonstration record. Physical authenticity and quality remain unverified.'},
 {label:'Expired / recalled',state:'do_not_use',lot_code:'DEMO-LOT-EXPIRED',message:'Synthetic product record is expired or recalled. Do not use or sell the item.'},
 {label:'Suspicious activity',state:'caution',lot_code:'DEMO-LOT-CLONE',message:'Synthetic signals indicate inconsistent activity. This is not a confirmed counterfeit determination.'},
 {label:'Unknown identifier',state:'unverifiable',message:'No matching demonstration record. An unknown code does not by itself establish a counterfeit product.'}
];
export default function Consumer(){
 const [token,setToken]=useState(''),[result,setResult]=useState<Result|null>(null),[demo,setDemo]=useState(true),[loading,setLoading]=useState(false),[message,setMessage]=useState(''),[camera,setCamera]=useState(false),[cameraError,setCameraError]=useState(''),[reportOpen,setReportOpen]=useState(false),[reason,setReason]=useState('Suspected tampering'),[details,setDetails]=useState(''),[reportComplete,setReportComplete]=useState(false);
 const video=useRef<HTMLVideoElement|null>(null),cameraRef=useRef<MediaStream|null>(null);
 useEffect(()=>{if(!camera)return;let running=true,raf=0;
 async function initialize(){try{const stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'}},audio:false});if(!running){stream.getTracks().forEach(t=>t.stop());return}cameraRef.current=stream;
 if(video.current){video.current.srcObject=stream;await video.current.play()}
 const Decoder=(window as unknown as {BarcodeDetector?:new(options:{formats:string[]})=>{detect:(v:HTMLVideoElement)=>Promise<Array<{rawValue:string}>>}}).BarcodeDetector;
 if(!Decoder){setCameraError('Camera-based QR decoding is not supported in this browser. Enter the code manually.');return}
 const detector=new Decoder({formats:['qr_code']});const loop=async()=>{if(!running||!video.current)return;try{const matches=await detector.detect(video.current);if(matches[0]?.rawValue){setDemo(false);setToken(matches[0].rawValue);setCamera(false);setMessage('Code captured. Select Verify code to check its digital record.');return}}catch{}if(running)raf=requestAnimationFrame(()=>void loop())};void loop()
 }catch(e){setCameraError(e instanceof Error?e.message:'Camera access was denied. Please enter the code manually.')}}
 void initialize();return()=>{running=false;cancelAnimationFrame(raf);cameraRef.current?.getTracks().forEach(t=>t.stop());cameraRef.current=null;if(video.current)video.current.srcObject=null}
 },[camera]);
 async function verify(e:React.FormEvent){e.preventDefault();setMessage('');setResult(null);setReportComplete(false);setDemo(false);
 setLoading(true);try{
 const response=await fetch('/api/v1/consumer/verify',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:token.trim()})});
 const output=await response.json();if(!response.ok)throw new Error(output.error||output.message||'Verification unavailable');
 setResult(output as Result);
 }catch(e){setResult({state:'service_unavailable',message:e instanceof Error?e.message:'Please try again later'})}finally{setLoading(false)}}
 function setScenario(p:typeof presets[number]){setDemo(true);setToken('');setResult({state:p.state,lot_code:p.lot_code,message:p.message});setReportComplete(false);setMessage('Illustrative scenario — not a live lookup.')}
 async function submitReport(e:React.FormEvent){e.preventDefault();setLoading(true);setReportComplete(false);try{
 const map:Record<string,string>={'Suspected tampering':'suspected_tampering','Altered expiry or lot information':'altered_expiry','Unexpected packaging':'unexpected_packaging','Possible adverse effect':'adverse_effect','Other concern':'other'};
 const response=await fetch('/api/v1/consumer/report',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:token.trim()||undefined,reason:map[reason]||'other',details:details.trim()})});
 const output=await response.json();if(!response.ok)throw new Error(output.error||'Report could not be saved');
 setReportComplete(true);setMessage('Your concern was saved in VeriTrust’s demonstration database. Reference: '+output.reference+'. This is not a submission to NAFDAC or another regulator.');
 }catch(e){setMessage(e instanceof Error?e.message:'Report could not be saved')}finally{setLoading(false)}}
 const title=result?.state==='matched_record'?'Digital record matched':result?.state==='do_not_use'?'Do not use this product':result?.state==='caution'?'Check this product carefully':result?.state==='service_unavailable'?'Verification temporarily unavailable':'Unable to authenticate';
 return <main className="cv"><header className="cv-head"><a href="/" className="cv-logo">⬡ VeriTrust<span>.</span></a><span className="cv-beta">DEMO ENVIRONMENT</span></header>
 <div className="cv-wrap"><div className="cv-hero"><div className="cv-eyebrow">PRODUCT VERIFICATION</div><h1>Know what you’re holding.</h1><p>Check a product identifier before using or purchasing a product. Your safety deserves more than assumptions.</p></div>
 <section className="cv-panel"><div className="cv-panelhead"><div><span className="cv-step">01 / VERIFY</span><h2>Scan or enter a product code</h2></div><span className="cv-qr">⌗</span></div><div className="cv-scan"><div className="cv-scanglyph">⌗</div><b>Check a serialized product label</b><small>Camera scanner on supported devices · HTTPS required</small><button type="button" onClick={()=>{setCameraError('');setCamera(x=>!x)}} className="cv-secondary">{camera?'Close camera':'Use phone camera'}</button></div>
 {camera&&<div className="cv-camera"><video ref={video} muted playsInline/><small>Point at a QR code</small></div>}{cameraError&&<p className="cv-error">{cameraError}</p>}
 <form onSubmit={verify} className="cv-form"><label htmlFor="cv-code">Enter code manually</label><input id="cv-code" autoComplete="off" maxLength={256} value={token} onChange={e=>{setToken(e.target.value);setDemo(false)}} placeholder="Enter or paste the security code"/><button disabled={loading||!token.trim()} className="cv-primary">{loading?'Checking…':'Verify product →'}</button></form>
 <p className="cv-footnote">Anonymous lookups are available only against VeriTrust's synthetic pilot registry, subject to protective limits. Never use this prototype to decide whether a real medicine or baby formula is safe.</p></section>
 <section className="cv-panel cv-presets"><span className="cv-step">02 / DEMONSTRATION</span><h2>Explore verification outcomes</h2><p>These examples are generated scenarios, not actual authentication results.</p><div className="cv-choices">{presets.map(p=><button onClick={()=>setScenario(p)} key={p.label}>{p.label}<span>→</span></button>)}</div></section>
 {result&&<section aria-live="polite" className={'cv-result '+result.state}><div className="cv-resulticon">{result.state==='matched_record'?'✓':result.state==='do_not_use'?'!':result.state==='caution'?'!':result.state==='service_unavailable'?'⌛':'?'}</div><span className="cv-step">VERIFICATION OUTCOME {demo?'· DEMONSTRATION':'· SYNTHETIC REGISTRY LOOKUP'}</span><h2>{title}</h2><p>{result.message}</p>{result.lot_code&&<div className="cv-info"><span>Recorded batch</span><b>{result.lot_code}</b></div>}<p className="cv-warning">A matching digital record does not establish the identity, quality, composition or safety of the physical product.</p><button className="cv-secondary" onClick={()=>setReportOpen(true)}>Report a concern</button></section>}
 {!!message&&<p className="cv-notice" role="status">{message}</p>}
 <section className="cv-panel cv-report"><span className="cv-step">03 / CUSTOMER SAFETY</span><h2>Something doesn't look right?</h2><p>Broken packaging, suspicious seals, altered dates, unexpected smell or quality concerns deserve attention.</p><button className="cv-secondary" onClick={()=>setReportOpen(x=>!x)}>{reportOpen?'Close report form':'Report suspicious product →'}</button>
 {reportOpen&&<form onSubmit={submitReport} className="cv-form"><label htmlFor="cv-reason">Reason for concern</label><select id="cv-reason" value={reason} onChange={e=>setReason(e.target.value)}><option>Suspected tampering</option><option>Altered expiry or lot information</option><option>Unexpected packaging</option><option>Possible adverse effect</option><option>Other concern</option></select><label htmlFor="cv-details">What happened?</label><textarea id="cv-details" minLength={10} maxLength={800} rows={4} placeholder="Describe the concern without providing private personal information." value={details} onChange={e=>setDetails(e.target.value)} required/><button className="cv-primary" disabled={details.trim().length<10}>Preview report</button>{reportComplete&&<div className="cv-reportnotice">Saved to VeriTrust's demonstration database only. This is not an official regulatory report. Keep the packaging and contact the retailer or appropriate regulator.</div>}</form>}
 </section><footer className="cv-footer">VeriTrust prototype · Synthetic records · Not affiliated with NAFDAC · Do not rely on this demonstration for a real product safety decision.</footer></div></main>
}