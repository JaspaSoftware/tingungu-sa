import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Terms & Conditions",
            style: TextStyle(color: Colors.white)),

        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Tingungu Terms of Service",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                  "By creating an account, you agree to abide by Tingungu’s terms of service. "
                      "This includes using the app responsibly, respecting others, and following community guidelines."),
              SizedBox(height: 20),
              Text(
                "Privacy Policy",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                  "Your data is securely stored and will never be sold to third parties. "
                      "We collect minimal information needed for functionality."),
              SizedBox(height: 20),
              Text(
                "POPIA Compliance",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                  "We adhere to the Protection of Personal Information Act (POPIA) and take "
                      "your privacy seriously."),
              SizedBox(height: 30),
              Center(
                child: Text(
                  "© 2026 Tingungu SA (Pty) Ltd • Developed by Jaspa",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
