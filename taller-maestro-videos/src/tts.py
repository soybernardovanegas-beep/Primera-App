import sys,json,base64,wave,time,urllib.request,urllib.error
URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash-tts:generateContent"
STYLE="Di esto en español latinoamericano neutro, con acento colombiano suave, voz masculina cercana y segura, de maestro de obra a maestro de obra, ritmo ágil pero claro: "
def tts(text,out,voice="Orus"):
    body={"contents":[{"parts":[{"text":STYLE+text}]}],"generationConfig":{"responseModalities":["AUDIO"],"speechConfig":{"voiceConfig":{"prebuiltVoiceConfig":{"voiceName":voice}}}}}
    for i in range(6):
        try:
            r=urllib.request.Request(URL,json.dumps(body).encode(),{"Content-Type":"application/json"})
            d=json.load(urllib.request.urlopen(r,timeout=45))
            pcm=base64.b64decode(d["candidates"][0]["content"]["parts"][0]["inlineData"]["data"])
            w=wave.open(out,"wb");w.setnchannels(1);w.setsampwidth(2);w.setframerate(24000);w.writeframes(pcm);w.close();return True
        except urllib.error.HTTPError as e:
            msg=e.read()[:200];print("err",e.code,msg,file=sys.stderr);time.sleep(8*(i+1))
        except Exception as e:
            print("err",e,file=sys.stderr);time.sleep(5)
    return False
if __name__=="__main__":
    print(tts(sys.argv[1],sys.argv[2]))
