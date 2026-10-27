if (-not ('Re4ModelRead' -as [type])) {
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Re4ModelRead {
 [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr process, IntPtr address, byte[] bytes, UIntPtr size, out UIntPtr read);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
 public static byte[] Read(IntPtr process, long address, int count) {
  if (address < 65536 || count <= 0 || count > 8192) return null;
  byte[] buffer = new byte[count];
  UIntPtr read;
  if (!ReadProcessMemory(process, new IntPtr(address), buffer, new UIntPtr((uint)count), out read) || read.ToUInt64() != (ulong)count) return null;
  return buffer;
 }
 public static bool SelfTest() {
  IntPtr pointer = Marshal.AllocHGlobal(7);
  IntPtr process = OpenProcess(0x410, false, System.Diagnostics.Process.GetCurrentProcess().Id);
  try {
   byte[] expected = new byte[] { 0xF7,0x40,0x58,0,0,0,0x40 };
   Marshal.Copy(expected,0,pointer,7);
   byte[] actual = Read(process,pointer.ToInt64(),7);
   return actual != null && BitConverter.ToString(actual) == BitConverter.ToString(expected);
  } finally { if (process != IntPtr.Zero) CloseHandle(process); Marshal.FreeHGlobal(pointer); }
 }
}
'@
}
