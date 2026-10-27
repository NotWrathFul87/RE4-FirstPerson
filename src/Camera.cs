using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

// x86 CameraQuasiFPS::hitCheck call wrapper; written independently for this mod.
public static class Re4CameraHook {
 [DllImport("kernel32.dll",SetLastError=true)] public static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern IntPtr VirtualAllocEx(IntPtr process,IntPtr address,UIntPtr size,uint allocation,uint protect);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool VirtualProtectEx(IntPtr process,IntPtr address,UIntPtr size,uint protect,out uint previous);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool WriteProcessMemory(IntPtr process,IntPtr address,byte[] bytes,UIntPtr size,out UIntPtr written);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool FlushInstructionCache(IntPtr process,IntPtr address,UIntPtr size);
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenThread(uint access,bool inherit,uint id);
 [DllImport("kernel32.dll",SetLastError=true)] static extern uint SuspendThread(IntPtr thread);
 [DllImport("kernel32.dll",SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
 public static bool Write(IntPtr process,long address,byte[] bytes) {
  UIntPtr written; return WriteProcessMemory(process,new IntPtr(address),bytes,new UIntPtr((uint)bytes.Length),out written)&&written.ToUInt64()==(ulong)bytes.Length;
 }
 // Suspend target threads only for the five-byte call replacement. Never free
 // the wrapper while a suspended thread could still have a return address in it.
 public static void ReplaceCall(IntPtr process,int pid,long address,byte[] bytes) {
  var suspended=new List<IntPtr>(); uint previous=0; bool writable=false;
  try {
   using(var target=System.Diagnostics.Process.GetProcessById(pid)) {
    foreach(System.Diagnostics.ProcessThread thread in target.Threads) {
     IntPtr handle=OpenThread(2,false,(uint)thread.Id);
     if(handle==IntPtr.Zero) throw new InvalidOperationException("Could not open a game thread.");
     if(SuspendThread(handle)==UInt32.MaxValue){CloseHandle(handle);throw new InvalidOperationException("Could not suspend a game thread.");}
     suspended.Add(handle);
    }
   }
   if(!VirtualProtectEx(process,new IntPtr(address),new UIntPtr(5u),0x40,out previous)) throw new InvalidOperationException("Could not change the camera call memory protection.");
   writable=true;
   if(!Write(process,address,bytes)) throw new InvalidOperationException("Could not write the camera call.");
   if(!FlushInstructionCache(process,new IntPtr(address),new UIntPtr(5u))) throw new InvalidOperationException("Could not flush the instruction cache.");
  } finally {
   if(writable){uint ignored;VirtualProtectEx(process,new IntPtr(address),new UIntPtr(5u),previous,out ignored);}
   for(int i=suspended.Count-1;i>=0;i--){ResumeThread(suspended[i]);CloseHandle(suspended[i]);}
  }
 }
 public static byte[] Call(uint source,uint destination){
  var bytes=new List<byte>();bytes.Add(0xE8);bytes.AddRange(BitConverter.GetBytes(unchecked((int)(destination-source-5))));return bytes.ToArray();
 }

 sealed class Assembler {
  public List<byte> Bytes=new List<byte>();
  Dictionary<string,int> labels=new Dictionary<string,int>();
  List<Tuple<int,string>> fixups=new List<Tuple<int,string>>();
  public void Emit(params byte[] bytes){Bytes.AddRange(bytes);}
  public void U32(uint value){Bytes.AddRange(BitConverter.GetBytes(value));}
  public void Label(string name){labels.Add(name,Bytes.Count);}
  public void Branch(byte condition,string label){Emit(0x0F,condition);fixups.Add(Tuple.Create(Bytes.Count,label));U32(0);}
  public void Jump(string label){Emit(0xE9);fixups.Add(Tuple.Create(Bytes.Count,label));U32(0);}
  public byte[] Finish(){foreach(var f in fixups){byte[] rel=BitConverter.GetBytes(labels[f.Item2]-f.Item1-4);for(int i=0;i<4;i++)Bytes[f.Item1+i]=rel[i];}return Bytes.ToArray();}
 }
 public static byte[] Build(uint code,uint original,uint playerPointer,uint globalPointer,uint data){
  var a=new Assembler();
  for(int i=0;i<3;i++)a.Emit(0xFF,0x74,0x24,0x0C);
  a.Emit(Call(code+(uint)a.Bytes.Count,original));
  a.Emit(0x9C,0x60);
  a.Emit(0x80,0x3D);a.U32(data);a.Emit(0);a.Branch(0x84,"exit");
  a.Emit(0xA1);a.U32(globalPointer);a.Emit(0x85,0xC0);a.Branch(0x84,"exit");
  a.Emit(0xF7,0x80,0x1C,0x50,0,0);a.U32(0x14001000);a.Branch(0x85,"exit");
  a.Emit(0x0F,0xB6,0x90,0xC8,0x4F,0,0); // edx = controlled character
  a.Emit(0x83,0xFA,6);a.Branch(0x84,"leon");
  a.Emit(0x85,0xD2);a.Branch(0x84,"kindReady");
  a.Emit(0x83,0xFA,1);a.Branch(0x85,"exit");a.Jump("kindReady");
  a.Label("leon");a.Emit(0x31,0xD2);
  a.Label("kindReady");
  a.Emit(0x3B,0x15);a.U32(data+8);a.Branch(0x85,"exit"); // must match validated model role
  a.Emit(0xA1);a.U32(playerPointer);a.Emit(0x85,0xC0);a.Branch(0x84,"exit");
  a.Emit(0x80,0xB8,0xFC,0,0,0,0);a.Branch(0x85,"exit");
  a.Emit(0x80,0xB8,0xFD,0,0,0,9);a.Branch(0x84,"exit");
  a.Emit(0x80,0xB8,0xFD,0,0,0,16);a.Branch(0x84,"exit");
  a.Emit(0x85,0xD2);a.Branch(0x85,"height");
  a.Emit(0x80,0xB8,0xFD,0,0,0,14);a.Branch(0x84,"exit");
  a.Emit(0x80,0xB8,0xFD,0,0,0,19);a.Branch(0x84,"exit");
  a.Emit(0x80,0xB8,0xFD,0,0,0,7);a.Branch(0x84,"exit");
  a.Emit(0x80,0xB8,0xFD,0,0,0,12);a.Branch(0x84,"exit");
  a.Label("height");
  a.Emit(0x8B,0x0D);a.U32(data+20); // Leon height
  a.Emit(0x85,0xD2);a.Branch(0x84,"heightReady");
  a.Emit(0x8B,0x0D);a.U32(data+28); // Ashley height
  a.Label("heightReady");
  a.Emit(0x8B,0x44,0x24,0x30,0x85,0xC0);a.Branch(0x84,"exit");
  a.Emit(0xFF,0x05);a.U32(data+4);
  a.Emit(0x51); // chosen height on stack; all remaining paths balance this push
  for(int axis=0;axis<3;axis++){
   a.Emit(0xD9,0x40,(byte)(12+axis*4));
   if(axis==0)a.Emit(0xD8,0x20);else a.Emit(0xD8,0x60,(byte)(axis*4));
   if(axis==1)a.Emit(0xD8,0x04,0x24);else{a.Emit(0xD8,0x05);a.U32(data+16+(uint)(axis*4));}
   a.Emit(0xD9,0x58,(byte)(12+axis*4));
  }
  a.Emit(0xC7,0);a.U32(0);
  a.Emit(0x8B,0x14,0x24,0x89,0x50,4);
  a.Emit(0xC7,0x40,8);a.U32(0);
  a.Emit(0x83,0xC4,4);
  a.Label("exit");a.Emit(0x61,0x9D,0xC2,0x0C,0);
  return a.Finish();
 }
}
public static class Re4SessionState {
 public static volatile bool JetSkiReady=false;
 public static volatile int BodyRole=-1;
}
