import Header from "./components/Header";
import ListForm from "./components/ListForm";
import Listings from "./components/Listings";

export default function App() {
  return (
    <div className="min-h-screen bg-zinc-50">
      <Header />
      <main className="mx-auto max-w-5xl px-6 py-8 space-y-6">
        <ListForm />
        <Listings />
      </main>
    </div>
  );
  
}

