importScripts("https://www.gstatic.com/firebasejs/10.12.4/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.4/firebase-messaging-compat.js");

// 🔥 INSERISCI I TUOI DATI QUI (li hai appena copiati)
const firebaseConfig = {
  apiKey: "AIzaSyBEkv6cH_cLUMiq3qoXlybvnuan3Em94WQ",
  authDomain: "canilepensioni.firebaseapp.com",
  projectId: "canilepensioni",
  storageBucket: "canilepensioni.firebasestorage.app",
  messagingSenderId: "1076405604277",
  appId: "1:1076405604277:web:06b95fd4a04ae79c5213fc",
  measurementId: "G-185584N56R"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Ascolta i messaggi in background
messaging.onBackgroundMessage((payload) => {
  console.log("📩 Notifica in background ricevuta:", payload);
  
  // La notifica verrà mostrata automaticamente dal browser
  // se il payload contiene il campo 'notification'
  return true;
});