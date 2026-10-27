if (-not ('Re4ModelWrite' -as [type])) {
 Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Re4ModelWrite {
 [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
 [DllImport("kernel32.dll", SetLastError=true)] static extern bool WriteProcessMemory(IntPtr process,IntPtr address,byte[] data,UIntPtr count,out UIntPtr written);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
 public static bool WriteFlag(IntPtr handle,long address,uint flag) {
  UIntPtr written;
  return WriteProcessMemory(handle,new IntPtr(address),BitConverter.GetBytes(flag),new UIntPtr(4u),out written) && written.ToUInt64()==4;
 }
 public static bool SelfTest() {
  IntPtr memory=Marshal.AllocHGlobal(4);
  IntPtr handle=OpenProcess(0x438,false,System.Diagnostics.Process.GetCurrentProcess().Id);
  try {
   Marshal.WriteInt32(memory,9);
   return WriteFlag(handle,memory.ToInt64(),1u) && Marshal.ReadInt32(memory)==1 && WriteFlag(handle,memory.ToInt64(),9u) && Marshal.ReadInt32(memory)==9;
  } finally { if(handle!=IntPtr.Zero) CloseHandle(handle); Marshal.FreeHGlobal(memory); }
 }
}
'@
}
