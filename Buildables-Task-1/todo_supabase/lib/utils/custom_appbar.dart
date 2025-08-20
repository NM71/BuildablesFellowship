import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomAppbar extends StatelessWidget {
  const CustomAppbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/supabase-logo.svg',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 20),
              Text(
                'T O D O ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ColorScheme.of(context).primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
