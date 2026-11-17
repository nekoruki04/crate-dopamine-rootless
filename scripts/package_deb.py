#!/usr/bin/env python3
import os
import sys
import tarfile
import tempfile
import subprocess
import shutil

def make_tar_gz(source_dir, output_file, is_control=False):
    with tarfile.open(output_file, "w:gz", format=tarfile.GNU_FORMAT) as tar:
        for root, dirs, files in os.walk(source_dir):
            rel_dir = os.path.relpath(root, source_dir)
            if rel_dir == ".":
                dir_entry = "."
            else:
                dir_entry = "./" + rel_dir
            
            tar_info = tar.gettarinfo(root, arcname=dir_entry)
            tar_info.uid = 0
            tar_info.gid = 0
            tar_info.uname = "root"
            tar_info.gname = "wheel"
            if not is_control and rel_dir != ".":
                tar_info.mode = 0o755
            tar.addfile(tar_info)

            for f in files:
                full_path = os.path.join(root, f)
                if rel_dir == ".":
                    arcname = "./" + f
                else:
                    arcname = "./" + os.path.join(rel_dir, f)
                
                tar_info = tar.gettarinfo(full_path, arcname=arcname)
                tar_info.uid = 0
                tar_info.gid = 0
                tar_info.uname = "root"
                tar_info.gname = "wheel"
                
                # Executable permissions for binaries and scripts
                if is_control:
                    if f in ["postinst", "prerm", "postrm", "preinst"]:
                        tar_info.mode = 0o755
                    else:
                        tar_info.mode = 0o644
                else:
                    if os.access(full_path, os.X_OK) or f in ["Crate"] or full_path.endswith((".dylib", ".framework/slirp", ".framework/glib", ".framework/EGL", ".framework/GLESv2", ".framework/epoxy", ".framework/virglrenderer.1", ".framework/MoltenVK")):
                        tar_info.mode = 0o755
                    else:
                        tar_info.mode = 0o644
                
                if tar_info.isreg():
                    with open(full_path, "rb") as fp:
                        tar.addfile(tar_info, fp)
                else:
                    tar.addfile(tar_info)

def main():
    workspace = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    app_source = os.path.expanduser("~/Library/Developer/Xcode/DerivedData/Crate-crjdzcswotqhwafvpdsjtvyexgnc/Build/Products/Release-iphoneos/Crate.app")
    debian_dir = os.path.join(workspace, "CrateRootless", "Packaging", "DEBIAN")
    build_dir = os.path.join(workspace, "build")
    os.makedirs(build_dir, exist_ok=True)
    
    primary_deb = os.path.join(build_dir, "crate-dopamine-rootless_1.0.0_iphoneos-arm.deb")
    legacy_deb = os.path.join(build_dir, "crate-rootless_1.0.0_iphoneos-arm.deb")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        staging_dir = os.path.join(tmpdir, "staging")
        # Canonical Dopamine rootless path: /var/jb/Applications/Crate.app
        app_dest = os.path.join(staging_dir, "var", "jb", "Applications", "Crate.app")
        os.makedirs(app_dest, exist_ok=True)
        
        print(f"[*] Copying {app_source} to {app_dest}...")
        subprocess.check_call(["rsync", "-a", app_source + "/", app_dest + "/"])
        
        # Verify and re-sign main binary and frameworks inside staging
        # Retarget main binary to minos 16.0 for iPadOS 16.1.1 compatibility
        crate_bin = os.path.join(app_dest, "Crate")
        print(f"[*] Setting minos to 16.0 on {crate_bin}...")
        subprocess.check_call(["vtool", "-set-build-version", "ios", "16.0", "18.5", "-replace", "-output", crate_bin, crate_bin])
        
        entitlements = os.path.join(workspace, "src", "crate-ios", "Resources", "Crate.entitlements")
        print(f"[*] Signing {crate_bin} with {entitlements}...")
        subprocess.check_call(["ldid", f"-S{entitlements}", crate_bin])
        
        fw_dir = os.path.join(app_dest, "Frameworks")
        if os.path.isdir(fw_dir):
            for fw in os.listdir(fw_dir):
                if fw.endswith(".framework"):
                    base = os.path.splitext(fw)[0]
                    target = os.path.join(fw_dir, fw, base)
                    if os.path.isfile(target):
                        subprocess.check_call(["ldid", "-S", target])
        
        control_tar = os.path.join(tmpdir, "control.tar.gz")
        data_tar = os.path.join(tmpdir, "data.tar.gz")
        
        print("[*] Generating control.tar.gz...")
        make_tar_gz(debian_dir, control_tar, is_control=True)
        
        print("[*] Generating data.tar.gz...")
        make_tar_gz(staging_dir, data_tar, is_control=False)
        
        debian_binary = os.path.join(tmpdir, "debian-binary")
        with open(debian_binary, "wb") as f:
            f.write(b"2.0\n")
            
        print(f"[*] Assembling Debian package -> {primary_deb}...")
        if os.path.exists(primary_deb):
            os.remove(primary_deb)
        subprocess.check_call(["/usr/bin/ar", "-rc", primary_deb, debian_binary, control_tar, data_tar], cwd=tmpdir)
        
        # Also copy / link legacy name for full compatibility
        shutil.copyfile(primary_deb, legacy_deb)
            
    print(f"[+] Package created successfully: {primary_deb} ({os.path.getsize(primary_deb)} bytes)")
    print(f"[+] Legacy package alias: {legacy_deb}")

if __name__ == "__main__":
    main()
