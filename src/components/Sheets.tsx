import React, { useState } from 'react';

// Define the shape of a row in the sheet
interface SheetRow {
  id: number;
  date: string;
  description: string;
  category: string;
  amount: number;
  type: 'credit' | 'debit';
}

const Sheets: React.FC = () => {
  // Sample initial data
  const [rows, setRows] = useState<SheetRow[]>([
    { id: 1, date: '2025-10-21', description: 'Office Supplies', category: 'Expense', amount: 45.00, type: 'debit' },
    { id: 2, date: '2025-10-22', description: 'Client Payment', category: 'Income', amount: 1200.00, type: 'credit' },
  ]);

  const [newRow, setNewRow] = useState<Partial<SheetRow>>({});

  const handleAddRow = () => {
    if (!newRow.description || !newRow.amount) return;
    
    const row: SheetRow = {
      id: Date.now(),
      date: newRow.date || new Date().toISOString().split('T')[0],
      description: newRow.description,
      category: newRow.category || 'General',
      amount: Number(newRow.amount),
      type: (newRow.type as 'credit' | 'debit') || 'debit',
    };

    setRows([...rows, row]);
    setNewRow({}); // Reset form
  };

  const handleDelete = (id: number) => {
    setRows(rows.filter(r => r.id !== id));
  };

  return (
    <div className="p-4 bg-white shadow rounded-lg">
      <h2 className="text-xl font-bold mb-4 text-gray-800">Transaction Sheet</h2>
      
      {/* Simple Table */}
      <div className="overflow-x-auto">
        <table className="min-w-full text-left text-sm whitespace-nowrap">
          <thead className="uppercase tracking-wider border-b-2 border-gray-200 bg-gray-50">
            <tr>
              <th scope="col" className="px-6 py-4">Date</th>
              <th scope="col" className="px-6 py-4">Description</th>
              <th scope="col" className="px-6 py-4">Category</th>
              <th scope="col" className="px-6 py-4 text-right">Amount</th>
              <th scope="col" className="px-6 py-4 text-center">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {rows.map((row) => (
              <tr key={row.id} className="hover:bg-gray-50">
                <td className="px-6 py-4">{row.date}</td>
                <td className="px-6 py-4 font-medium text-gray-900">{row.description}</td>
                <td className="px-6 py-4 text-gray-500">{row.category}</td>
                <td className={`px-6 py-4 text-right font-bold ${row.type === 'credit' ? 'text-green-600' : 'text-red-600'}`}>
                  {row.type === 'debit' ? '-' : '+'} ${row.amount.toFixed(2)}
                </td>
                <td className="px-6 py-4 text-center">
                  <button 
                    onClick={() => handleDelete(row.id)}
                    className="text-red-500 hover:text-red-700"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            
            {/* Input Row */}
            <tr className="bg-blue-50">
              <td className="px-6 py-2">
                <input 
                  type="date" 
                  className="p-1 border rounded w-full"
                  value={newRow.date || ''}
                  onChange={e => setNewRow({...newRow, date: e.target.value})}
                />
              </td>
              <td className="px-6 py-2">
                <input 
                  type="text" 
                  placeholder="Desc" 
                  className="p-1 border rounded w-full"
                  value={newRow.description || ''}
                  onChange={e => setNewRow({...newRow, description: e.target.value})}
                />
              </td>
              <td className="px-6 py-2">
                <input 
                  type="text" 
                  placeholder="Category" 
                  className="p-1 border rounded w-full"
                  value={newRow.category || ''}
                  onChange={e => setNewRow({...newRow, category: e.target.value})}
                />
              </td>
              <td className="px-6 py-2">
                <input 
                  type="number" 
                  placeholder="0.00" 
                  className="p-1 border rounded w-full text-right"
                  value={newRow.amount || ''}
                  onChange={e => setNewRow({...newRow, amount: parseFloat(e.target.value)})}
                />
              </td>
              <td className="px-6 py-2 text-center">
                <button 
                  onClick={handleAddRow}
                  className="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700"
                >
                  Add
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Sheets;
