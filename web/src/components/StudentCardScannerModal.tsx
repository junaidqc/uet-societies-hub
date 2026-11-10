import React, { useState } from 'react';
import { ScanLine, X, CheckCircle, CreditCard, Sparkles, Building, Hash } from 'lucide-react';

interface StudentCardScannerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onScanned: (data: {
    rollNumber: string;
    department: string;
    semester: number;
    email: string;
    fullName?: string;
  }) => void;
}

const SAMPLE_CARDS = [
  { roll: '2025-CS-25', dept: 'Computer Science', semester: 2, name: 'Muhammad Zain' },
  { roll: '2022-CS-142', dept: 'Computer Science', semester: 8, name: 'Hamza Arshad' },
  { roll: '2023-EE-089', dept: 'Electrical Engineering', semester: 6, name: 'Ayesha Fatima' },
  { roll: '2024-ME-045', dept: 'Mechanical Engineering', semester: 4, name: 'Bilal Khan' },
];

export const StudentCardScannerModal: React.FC<StudentCardScannerModalProps> = ({
  isOpen,
  onClose,
  onScanned,
}) => {
  const [manualInput, setManualInput] = useState('');
  const [isScanning, setIsScanning] = useState(false);
  const [scannedResult, setScannedResult] = useState<{
    rollNumber: string;
    department: string;
    semester: number;
    email: string;
    fullName?: string;
  } | null>(null);

  if (!isOpen) return null;

  const parseRollNumber = (raw: string, defaultName?: string) => {
    const cleaned = raw.trim().toUpperCase();
    const parts = cleaned.split('-');
    let dept = 'Engineering';
    let semester = 2;

    if (parts.length >= 2) {
      const deptCode = parts[1];
      if (deptCode.includes('CS') || deptCode.includes('SE')) dept = 'Computer Science';
      else if (deptCode.includes('EE')) dept = 'Electrical Engineering';
      else if (deptCode.includes('ME')) dept = 'Mechanical Engineering';
      else if (deptCode.includes('CE')) dept = 'Civil Engineering';
      else if (deptCode.includes('CH')) dept = 'Chemical Engineering';

      const year = parseInt(parts[0], 10);
      if (!isNaN(year)) {
        const currentYear = 2026;
        semester = Math.min(8, Math.max(1, (currentYear - year) * 2));
      }
    }

    const emailUser = cleaned.toLowerCase().replace(/[^a-z0-9]/g, '');
    const email = `${emailUser}@student.uet.edu.pk`;

    return {
      rollNumber: cleaned,
      department: dept,
      semester,
      email,
      fullName: defaultName || `Student ${cleaned}`,
    };
  };

  const handleSelectSample = (sample: typeof SAMPLE_CARDS[0]) => {
    setIsScanning(true);
    setTimeout(() => {
      const email = sample.roll.toLowerCase().replace(/[^a-z0-9]/g, '') + '@student.uet.edu.pk';
      const parsed = {
        rollNumber: sample.roll,
        department: sample.dept,
        semester: sample.semester,
        email,
        fullName: sample.name,
      };
      setScannedResult(parsed);
      setIsScanning(false);
    }, 600);
  };

  const handleManualSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!manualInput) return;
    const parsed = parseRollNumber(manualInput);
    setScannedResult(parsed);
  };

  const handleConfirm = () => {
    if (scannedResult) {
      onScanned(scannedResult);
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-fadeIn">
      <div className="bg-slate-900 border border-slate-700/80 rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
              <ScanLine className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-white text-lg">Student Card Scanner</h3>
              <p className="text-xs text-slate-400">Scan or verify UET Student ID Barcode</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white p-2 rounded-lg hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 space-y-6">
          {/* Scanner Viewfinder */}
          <div className="relative h-48 rounded-xl bg-slate-950 border border-dashed border-emerald-500/40 overflow-hidden flex flex-col items-center justify-center">
            {/* Corner accents */}
            <div className="absolute top-2 left-2 w-6 h-6 border-t-2 border-l-2 border-emerald-400"></div>
            <div className="absolute top-2 right-2 w-6 h-6 border-t-2 border-r-2 border-emerald-400"></div>
            <div className="absolute bottom-2 left-2 w-6 h-6 border-b-2 border-l-2 border-emerald-400"></div>
            <div className="absolute bottom-2 right-2 w-6 h-6 border-b-2 border-r-2 border-emerald-400"></div>

            {/* Red/Green Laser Line */}
            <div className="absolute inset-x-8 h-0.5 bg-gradient-to-r from-transparent via-emerald-400 to-transparent shadow-[0_0_12px_#10b981] animate-bounce"></div>

            <div className="flex flex-col items-center text-center p-4">
              <CreditCard className="w-12 h-12 text-slate-600 mb-2" />
              <p className="text-sm font-medium text-slate-300">
                {isScanning ? 'Decoding Barcode...' : 'Position UET ID Barcode inside frame'}
              </p>
              <p className="text-xs text-slate-500 mt-1">Simulated Optical Character Recognition</p>
            </div>
          </div>

          {/* Quick Preset Samples */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-2 flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-amber-400" /> Or select a sample student card:
            </label>
            <div className="grid grid-cols-2 gap-2 mt-1">
              {SAMPLE_CARDS.map((sample) => (
                <button
                  key={sample.roll}
                  type="button"
                  onClick={() => handleSelectSample(sample)}
                  className="flex flex-col text-left p-2.5 rounded-lg bg-slate-800/60 border border-slate-700/60 hover:border-emerald-500/50 hover:bg-slate-800 transition group"
                >
                  <span className="font-mono text-xs font-semibold text-emerald-400 group-hover:text-emerald-300">
                    {sample.roll}
                  </span>
                  <span className="text-[11px] text-slate-300 truncate">{sample.name}</span>
                  <span className="text-[10px] text-slate-500">{sample.dept}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Manual Input Fallback */}
          <form onSubmit={handleManualSubmit} className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1">
              <Hash className="w-3 h-3" /> Or Enter Roll Number Manually
            </label>
            <div className="flex gap-2">
              <input
                type="text"
                placeholder="e.g. 2025-CS-25 or 2022-EE-104"
                value={manualInput}
                onChange={(e) => setManualInput(e.target.value)}
                className="flex-1 bg-slate-950 border border-slate-700 rounded-lg px-3.5 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 font-mono"
              />
              <button
                type="submit"
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-sm font-medium rounded-lg transition"
              >
                Decode
              </button>
            </div>
          </form>

          {/* Scanned Result Preview */}
          {scannedResult && (
            <div className="bg-emerald-950/40 border border-emerald-500/40 rounded-xl p-4 animate-fadeIn">
              <div className="flex items-center gap-2 text-emerald-400 font-semibold text-sm mb-3">
                <CheckCircle className="w-4 h-4" /> Card Verified & Decoded!
              </div>
              <div className="grid grid-cols-2 gap-2 text-xs">
                <div>
                  <span className="text-slate-400">Roll Number:</span>
                  <p className="font-mono font-medium text-white">{scannedResult.rollNumber}</p>
                </div>
                <div>
                  <span className="text-slate-400">Department:</span>
                  <p className="font-medium text-white">{scannedResult.department}</p>
                </div>
                <div>
                  <span className="text-slate-400">Current Semester:</span>
                  <p className="font-medium text-white">Semester {scannedResult.semester}</p>
                </div>
                <div>
                  <span className="text-slate-400">Official Student Email:</span>
                  <p className="font-mono text-emerald-300 truncate">{scannedResult.email}</p>
                </div>
              </div>

              <button
                type="button"
                onClick={handleConfirm}
                className="w-full mt-4 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-medium text-sm rounded-lg shadow-lg shadow-emerald-900/30 transition flex items-center justify-center gap-2"
              >
                <CheckCircle className="w-4 h-4" /> Use Verified Information
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
