from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess, shutil
root=Path(__file__).resolve().parent/'clips'
root.mkdir(exist_ok=True)
files=sorted((Path.home()/'Library/Application Support/com.apple.wallpaper/aerials/videos').glob('*.mov'))
def convert(pair):
 i,f=pair
 out=root/f'clip-{i}.mp4'
 subprocess.run([shutil.which('ffmpeg') or 'ffmpeg','-y','-v','error','-ss','3','-i',str(f),'-t','1.8','-an','-vf','scale=640:360','-r','30','-c:v','h264_videotoolbox','-b:v','1000k','-movflags','+faststart',str(out)],check=True)
 return out.name
with ThreadPoolExecutor(max_workers=2) as pool:
 for result in pool.map(convert,enumerate(files,1)): print(result)
