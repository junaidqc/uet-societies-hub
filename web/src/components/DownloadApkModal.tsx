import React from 'react';
import { X, Download, Smartphone, CheckCircle, Shield, FileCheck, ArrowDownToLine } from 'lucide-react';

interface DownloadApkModalProps {
  isOpen: boolean;
  onClose: () => void;
  onDownloadStarted?: () => void;
}

export const APK_RELEASE_URL =
  'https://github.com/junaidqc/uet-societies-hub/releases/download/latest/app-release.apk';

export const DownloadApkModal: React.FC<DownloadApkModalProps> = ({
  isOpen,
  onClose,
  onDownloadStarted,
}) => {
  if (!isOpen) return null;

  const handleDownload = () => {
    if (onDownloadStarted) onDownloadStarted();
    window.location.href = APK_RELEASE_URL;
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-fadeIn">
      <div className="bg-slate-900 border border-slate-700/80 rounded-3xl w-full max-w-md shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/40">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 flex items-center justify-center">
              <Smartphone className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-white text-base">Android Application</h3>
              <p className="text-[11px] text-slate-400">Official Mobile Client for UET Lahore</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 space-y-5 text-xs">
          {/* Release Specs Box */}
          <div className="bg-slate-950/80 border border-slate-800 rounded-2xl p-4 space-y-2.5">
            <div className="flex items-center justify-between text-slate-300">
              <span className="text-slate-500">Release Version:</span>
              <span className="font-mono font-bold text-emerald-400">v1.0.0 (Release)</span>
            </div>
            <div className="flex items-center justify-between text-slate-300">
              <span className="text-slate-500">Package Architecture:</span>
              <span className="font-mono text-white">Universal ARM64 / ARMv7 / x86_64</span>
            </div>
            <div className="flex items-center justify-between text-slate-300">
              <span className="text-slate-500">Package Size:</span>
              <span className="font-mono text-white">36.7 MB</span>
            </div>
            <div className="flex items-center justify-between text-slate-300">
              <span className="text-slate-500">Compatibility:</span>
              <span className="text-white">Android 8.0 (Oreo) and newer</span>
            </div>
            <div className="flex items-center justify-between text-slate-300">
              <span className="text-slate-500">Security:</span>
              <span className="text-emerald-400 flex items-center gap-1">
                <Shield className="w-3.5 h-3.5" /> Fastly Verified CDN
              </span>
            </div>
          </div>

          {/* Direct Download Button */}
          <button
            onClick={handleDownload}
            className="w-full py-3 px-4 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-2xl shadow-xl shadow-emerald-950/50 flex items-center justify-center gap-2 transition duration-150 text-sm"
          >
            <ArrowDownToLine className="w-4 h-4" />
            <span>Download app-release.apk (36.7 MB)</span>
          </button>

          {/* Installation Instructions */}
          <div className="p-3.5 rounded-2xl bg-slate-950/50 border border-slate-800/80 space-y-1.5 text-slate-400 text-[11px]">
            <p className="font-semibold text-slate-300 flex items-center gap-1.5">
              <FileCheck className="w-3.5 h-3.5 text-emerald-400" /> Fast Installation Guide:
            </p>
            <ol className="list-decimal list-inside space-y-1 pl-1 text-slate-400">
              <li>Click the download button above.</li>
              <li>Pull down notifications on your Android device and tap <code className="text-emerald-300">app-release.apk</code>.</li>
              <li>Tap <strong>Install</strong> (enable "Install unknown apps" if prompted).</li>
              <li>Open the app and test with <code className="text-emerald-300">2025@uet.edu.pk</code>.</li>
            </ol>
          </div>
        </div>
      </div>
    </div>
  );
};
