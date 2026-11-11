import React from 'react';
import { Smartphone, Shield, FileCheck, ArrowDownToLine } from 'lucide-react';
import { Modal } from './common/Modal';

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
  const handleDownload = () => {
    if (onDownloadStarted) onDownloadStarted();
    window.location.href = APK_RELEASE_URL;
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Official Android Application"
      description="Native mobile client for UET Societies Hub"
      maxWidth="max-w-md"
    >
      <div className="p-6 space-y-5 text-xs">
        {/* Release Specs Box */}
        <div className="bg-slate-950/80 border border-slate-800 rounded-2xl p-4 space-y-2.5">
          <div className="flex items-center justify-between text-slate-300">
            <span className="text-slate-500">Release Version:</span>
            <span className="font-mono font-bold text-emerald-400">v1.0.0 (Production Release)</span>
          </div>
          <div className="flex items-center justify-between text-slate-300">
            <span className="text-slate-500">Architecture:</span>
            <span className="font-mono text-white">Universal ARM64 / ARMv7 / x86_64</span>
          </div>
          <div className="flex items-center justify-between text-slate-300">
            <span className="text-slate-500">Package Size:</span>
            <span className="font-mono text-white">36.7 MB</span>
          </div>
          <div className="flex items-center justify-between text-slate-300">
            <span className="text-slate-500">Compatibility:</span>
            <span className="text-white">Android 8.0 (Oreo) & newer</span>
          </div>
          <div className="flex items-center justify-between text-slate-300">
            <span className="text-slate-500">Security:</span>
            <span className="text-emerald-400 flex items-center gap-1 font-semibold">
              <Shield className="w-3.5 h-3.5" /> Verified GitHub Asset Release
            </span>
          </div>
        </div>

        {/* Direct Download Button */}
        <button
          type="button"
          onClick={handleDownload}
          className="w-full py-3 px-4 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-2xl shadow-xl shadow-emerald-950/50 flex items-center justify-center gap-2 transition duration-150 text-sm cursor-pointer"
        >
          <ArrowDownToLine className="w-4 h-4" />
          <span>Download app-release.apk (36.7 MB)</span>
        </button>

        {/* Fast Installation Guide */}
        <div className="p-3.5 rounded-2xl bg-slate-950/50 border border-slate-800/80 space-y-1.5 text-slate-400 text-[11px]">
          <p className="font-semibold text-slate-300 flex items-center gap-1.5">
            <FileCheck className="w-3.5 h-3.5 text-emerald-400" /> Fast Installation Guide:
          </p>
          <ol className="list-decimal list-inside space-y-1 pl-1 text-slate-400">
            <li>Click the download button above to retrieve the package.</li>
            <li>Pull down notifications on your Android device and tap <code className="text-emerald-300 font-mono">app-release.apk</code>.</li>
            <li>Select <strong>Install</strong> (toggle "Allow unknown sources" if prompted by Android).</li>
            <li>Launch the application and sign in with your official university credentials.</li>
          </ol>
        </div>
      </div>
    </Modal>
  );
};
