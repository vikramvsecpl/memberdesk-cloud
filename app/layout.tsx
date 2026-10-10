import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'MemberDesk | Gym & Study Library', description: 'Cloud management for gym memberships and fixed-seat self-study libraries.' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }
