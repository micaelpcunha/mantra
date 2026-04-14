import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initializeSupabase() async {
  await Supabase.initialize(
    url: 'https://uaupakkizxmwgcfrtnnz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhdXBha2tpenhtd2djZnJ0bm56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyODM4OTksImV4cCI6MjA4OTg1OTg5OX0.geYOIT8MCnXQ-yrFn-D3c15Zpg-81fSNkc7YurPBxTM',
  );
}
